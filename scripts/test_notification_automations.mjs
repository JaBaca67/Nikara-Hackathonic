import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/notification-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';

// Ejecuta la migración real en PostgreSQL local, sin webhook ni envíos FCM.
const db = new PGlite();
const user = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const business = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1';
const second = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc2';
const pending = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3';
const eco = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1';
let passed = 0;
async function check(name, run) {
  await run();
  passed++;
  console.log(`OK ${name}`);
}
async function scalar(sql, params = []) {
  return Object.values((await db.query(sql, params)).rows[0])[0];
}
async function count(type, owner = user) {
  return Number(await scalar('select count(*) from notifications where user_id=$1 and type=$2', [owner, type]));
}
async function login(owner) {
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [owner]);
}
async function trip(id, destination = business, completed = '2026-01-02T12:00:00Z') {
  return scalar('select sync_passport_notification_events($1::jsonb)', [JSON.stringify([{
    trip_id: id, business_id: destination, started_at: '2026-01-01T12:00:00Z', completed_at: completed,
  }])]);
}

try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create table profiles(id uuid primary key);
    create table businesses(id uuid primary key, name text not null, city text, status text);
    create table notifications(id uuid default gen_random_uuid(), user_id uuid references profiles(id),
      title text, body text, type text, reference_id uuid, is_read boolean default false,
      created_at timestamptz default now());
    create table user_favorites(user_id uuid references profiles(id), item_type text, item_id uuid,
      primary key(user_id,item_type,item_id));
    create table reviews(id uuid default gen_random_uuid(), user_id uuid references profiles(id),
      target_type text, target_id uuid, rating integer, comment text);
    create table eco_activities(id uuid primary key, title text not null, location text,
      start_time timestamptz, status text, requirements text[] default '{}');
    create table eco_participants(activity_id uuid references eco_activities(id) on delete cascade,
      user_id uuid references profiles(id), joined_at timestamptz default now(), primary key(activity_id,user_id));
    grant usage on schema public,auth to anon,authenticated,service_role;
    insert into profiles values ('${user}'),('${other}');
    insert into businesses values ('${business}','Café Uno','Matagalpa','aprobado'),
      ('${second}','Taller Dos','Masaya','aprobado'),('${pending}','Pendiente','León','pendiente');
  `);
  await db.exec(await readFile(new URL('../supabase/sql/045_action_notification_automations.sql', import.meta.url), 'utf8'));
  await login(user);

  await check('la migración se puede ejecutar dos veces', async () => {
    await db.exec(await readFile(new URL('../supabase/sql/045_action_notification_automations.sql', import.meta.url), 'utf8'));
  });
  await check('los visitantes anónimos no pueden activar ni publicar premios', async () => {
    await db.exec('set role anon');
    await assert.rejects(() => db.query('select enable_user_notification_automations()'), /permission denied/);
    await assert.rejects(() => db.query('select sync_passport_notification_events($1::jsonb)', ['[]']), /permission denied/);
    await db.exec('reset role');
  });
  await check('activar solo inscribe la cuenta propia y no pospone una programación existente', async () => {
    await db.query('select enable_user_notification_automations()');
    const scheduled = await scalar('select next_business_at::text from notification_automation_settings where user_id=$1', [user]);
    await db.query('select enable_user_notification_automations()');
    assert.equal(await scalar('select next_business_at::text from notification_automation_settings where user_id=$1', [user]), scheduled);
    assert.equal(Number(await scalar('select count(*) from notification_automation_settings')), 1);
  });
  await check('los favoritos desbloquean las dos insignias y no se repiten al quitar y volver a guardar', async () => {
    for (const id of [business, second, pending]) {
      await db.query("insert into user_favorites values ($1,'business',$2)", [user, id]);
    }
    assert.equal(await count('achievement_unlocked'), 2);
    await db.query('delete from user_favorites where user_id=$1 and item_id=$2', [user, pending]);
    await db.query("insert into user_favorites values ($1,'business',$2)", [user, pending]);
    assert.equal(await count('achievement_unlocked'), 2);
  });
  await check('borrar un aviso no permite volver a ganar la misma insignia', async () => {
    await db.query("delete from notifications where user_id=$1 and title like '%Guardián%' ", [user]);
    await db.query('delete from user_favorites where user_id=$1 and item_id=$2', [user, pending]);
    await db.query("insert into user_favorites values ($1,'business',$2)", [user, pending]);
    assert.equal(await count('achievement_unlocked'), 1);
  });
  await check('solo la primera reseña de negocio gana Viajero Consciente', async () => {
    await db.query("insert into reviews(user_id,target_type,target_id,rating) values ($1,'eco_activity',$2,5)", [user, eco]);
    assert.equal(await count('achievement_unlocked'), 1);
    await db.query("insert into reviews(user_id,target_type,target_id,rating) values ($1,'business',$2,5),($1,'business',$3,4)", [user, business, second]);
    assert.equal(await count('achievement_unlocked'), 2);
  });
  await check('el primer viaje gana una postal y una insignia; reintentar no duplica', async () => {
    assert.equal(await trip('viaje-1'), 1);
    assert.equal(await count('postcard_earned'), 1);
    assert.equal(await count('achievement_unlocked'), 3);
    assert.equal(await trip('viaje-1'), 0);
    assert.equal(await count('postcard_earned'), 1);
  });
  await check('las visitas repetidas suman viajes pero conservan una postal por negocio', async () => {
    await trip('viaje-2'); await trip('viaje-3');
    assert.equal(await count('postcard_earned'), 1);
    assert.equal(await count('achievement_unlocked'), 4);
    await trip('viaje-4', second); await trip('viaje-5', second);
    assert.equal(await count('postcard_earned'), 2);
    assert.equal(await count('achievement_unlocked'), 5);
  });
  await check('cuentas distintas mantienen independientes sus premios y viajes', async () => {
    await login(other); await trip('viaje-1');
    assert.equal(await count('postcard_earned', other), 1);
    assert.equal(await count('achievement_unlocked', other), 1);
    await db.exec('set role authenticated');
    assert.equal(Number(await scalar('select count(*) from notification_completed_trips')), 1);
    await assert.rejects(() => db.query('select run_notification_automations()'), /permission denied/);
    await db.exec('reset role'); await login(user);
  });
  await check('viajes inválidos y negocios sin aprobar no generan premios', async () => {
    await assert.rejects(() => trip('futuro', business, '2099-01-01T00:00:00Z'), /confirmar el viaje/);
    assert.equal(await trip('sin-aprobar', pending), 0);
    assert.equal(await count('postcard_earned'), 2);
  });
  await check('no hay recomendaciones antes de su hora; al vencer se recomienda un negocio aprobado', async () => {
    assert.equal((await scalar('select run_notification_automations()')).business_recommendations, 0);
    await db.query("update notification_automation_settings set next_business_at=now()-interval '1 minute'");
    assert.equal((await scalar('select run_notification_automations()')).business_recommendations, 1);
    assert.equal(await count('business_recommendation'), 1);
    assert.equal(await count('business_recommendation', other), 0);
    assert.notEqual(await scalar("select reference_id::text from notifications where type='business_recommendation'"), pending);
    const seconds = Number(await scalar('select extract(epoch from next_business_at-now()) from notification_automation_settings'));
    assert.ok(Math.abs(seconds-3600)<3 || Math.abs(seconds-7200)<3);
  });
  await check('el cron es idempotente y evita repetir consecutivamente el mismo negocio', async () => {
    assert.equal((await scalar('select run_notification_automations()')).business_recommendations, 0);
    const previous = await scalar('select last_business_id::text from notification_automation_settings');
    await db.query("update notification_automation_settings set next_business_at=now()-interval '1 second'");
    assert.equal((await scalar('select run_notification_automations()')).business_recommendations, 1);
    assert.notEqual(await scalar('select last_business_id::text from notification_automation_settings'), previous);
  });
  await check('desactivar las recomendaciones detiene los envíos siguientes', async () => {
    await db.query('select enable_user_notification_automations(false)');
    await db.query('select enable_user_notification_automations()');
    await db.query("update notification_automation_settings set next_business_at=now()-interval '1 minute'");
    assert.equal((await scalar('select run_notification_automations()')).business_recommendations, 0);
  });
  await check('unirse a ECO genera dos avisos; el RPC repetido comparte el mismo recibo', async () => {
    await db.query("insert into eco_activities values ($1,'Limpieza de playa','Pochomil',now()+interval '20 hours','aprobado',array['Guantes','Agua'])", [eco]);
    await db.query('insert into eco_participants(activity_id,user_id) values ($1,$2)', [eco, user]);
    assert.equal(await count('eco_activity_joined'), 1);
    assert.equal(await count('eco_activity_preparation'), 1);
    await db.query('select notify_eco_participation($1)', [eco]);
    assert.equal(await count('eco_activity_joined'), 1);
    assert.equal(await count('eco_activity_preparation'), 1);
  });
  await check('el recordatorio de 24 horas solo llega una vez a quienes participan', async () => {
    assert.equal((await scalar('select run_notification_automations()')).eco_reminders, 1);
    assert.equal((await scalar('select run_notification_automations()')).eco_reminders, 0);
    assert.equal(await count('eco_activity_reminder', other), 0);
  });
  await check('cambiar la fecha avisa al participante y genera el recordatorio de dos horas', async () => {
    await db.query("update eco_activities set start_time=now()+interval '1 hour' where id=$1", [eco]);
    assert.equal(await count('eco_activity_updated'), 1);
    assert.equal((await scalar('select run_notification_automations()')).eco_reminders, 1);
    assert.equal((await scalar('select run_notification_automations()')).eco_reminders, 0);
    assert.equal(await count('eco_activity_reminder'), 2);
  });
  await check('al abandonar se dejan de recibir recordatorios y cambios de la actividad', async () => {
    await db.query('delete from eco_participants where activity_id=$1 and user_id=$2', [eco, user]);
    await db.query("update eco_activities set location='Otro punto' where id=$1", [eco]);
    assert.equal(await count('eco_activity_updated'), 1);
    assert.equal((await scalar('select run_notification_automations()')).eco_reminders, 0);
  });
  await check('volver a unirse permite otra confirmación; dejar de publicar cancela los recordatorios', async () => {
    await db.query('insert into eco_participants(activity_id,user_id) values ($1,$2)', [eco, user]);
    assert.equal(await count('eco_activity_joined'), 2);
    await db.query("update eco_activities set status='rechazado' where id=$1", [eco]);
    assert.equal(await count('eco_activity_cancelled'), 1);
    assert.equal((await scalar('select run_notification_automations()')).eco_reminders, 0);
  });
  console.log(`${passed} verificaciones SQL aprobadas.`);
} finally {
  await db.close();
}
