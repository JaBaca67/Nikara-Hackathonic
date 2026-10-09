import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/notification-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
const owner = '30a57d65-a20c-407e-bd7f-d07d8c3c54da';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const migration = await readFile(new URL('../supabase/sql/047_route_descriptions.sql', import.meta.url), 'utf8');
const globalMigration = await readFile(new URL('../supabase/sql/048_global_creative_routes.sql', import.meta.url), 'utf8');
const rlsMigration = await readFile(new URL('../supabase/sql/029_enable_rls.sql', import.meta.url), 'utf8');
const seed = await readFile(new URL('../supabase/demo/xolotlan/prepared/import.sql', import.meta.url), 'utf8');
const catalog = JSON.parse(await readFile(new URL('./data/xolotlan_catalog.json', import.meta.url), 'utf8'));
const scalar = async (sql) => Object.values((await db.query(sql)).rows[0])[0];
try {
  // PostGIS operations only encode place coordinates. Stub those operations;
  // execute the real transaction, constraints, guards and joins in PostgreSQL.
  await db.exec(`
    create role anon;
    create role authenticated;
    create schema auth;
    create function auth.uid() returns uuid language sql as $$
      select nullif(current_setting('test.user_id',true),'')::uuid $$;
    create function is_admin() returns boolean language sql as $$
      select coalesce(current_setting('test.is_admin',true),'false')::boolean $$;
    create domain geography as text;
    create function st_makepoint(float8,float8) returns text language sql as $$ select $1::text||','||$2::text $$;
    create function st_setsrid(text,integer) returns text language sql as $$ select $1 $$;
    create table profiles(id uuid primary key, role text);
    create table businesses(id uuid primary key,owner_id uuid references profiles(id) on delete cascade,name text,category text,
      subcategory text,description text,city text,address_text text,location geography,phone text,schedules text,
      access_details text,other_notes text,photos text[],status text,is_verified boolean,show_host boolean);
    create table routes(id uuid primary key,owner_id uuid not null references profiles(id) on delete cascade,title text,days integer,
      is_public boolean,status text,image_urls text[]);
    create table route_stops(id uuid primary key,route_id uuid references routes(id),day_number integer,
      position integer,kind text,business_id uuid references businesses(id) on delete set null,title text,subtitle text,
      category text,image_path text,latitude float8,longitude float8);
    insert into profiles values('${owner}','emprendedor'),('${other}','turista');
    insert into routes(id,owner_id,title,days,is_public,status) values('${other}','${other}','Ruta anterior',1,false,'active');
  `);
  await db.exec(migration);
  await db.exec(migration);
  assert.equal(await scalar(`select description from routes where id='${other}'`), '');
  await assert.rejects(db.query(`update routes set description=repeat('x',501) where id='${other}'`));
  console.log('OK descripción antigua, migración repetible y límite de 500 caracteres');
  await db.exec(globalMigration);
  await db.exec(globalMigration);

  // Reuse a place that belongs to another profile, without changing its content.
  await db.exec(`insert into businesses(id,owner_id,name,city,status,description,photos)
    values('${other}','${other}','Puerto Salvador Allende','Managua','aprobado','Ficha existente',array['https://existing.example/photo.jpg']);`);
  await db.exec(seed);
  assert.equal(await scalar('select count(*) from businesses'), 51);
  assert.equal(await scalar('select count(*) from route_stops'), 58);
  assert.equal(await scalar(`select description from businesses where id='${other}'`), 'Ficha existente');
  const rows = (await db.query(`select r.title,s.title as stop,s.position from routes r join route_stops s on s.route_id=r.id
    order by r.title,s.position`)).rows;
  const byId = Object.fromEntries(catalog.businesses.map(p => [p.official_id, p.name]));
  for (const route of catalog.routes) {
    const saved = rows.filter(row => row.title === route.title);
    assert.deepEqual(saved.map(row => row.stop), route.stops.map(p => byId[p.official_id]));
    assert.deepEqual(saved.map(row => row.position), route.stops.map(p => p.order - 1));
  }
  assert.equal(await scalar(`select count(*) from route_stops where business_id='${other}'`), 3);
  assert.equal(await scalar(`select count(*) from route_stops where latitude is null`), 4);
  console.log('OK 51 lugares, 58 paradas, orden municipal, referencias sin navegación y reutilización');

  // A catalog original is always public. Personal copies keep their privacy.
  const routeId = await scalar(`select id from routes where title='Xolotlán · Ruta Natural'`);
  assert.equal(await scalar('select count(*) from routes where owner_id is null and is_public and catalog_name is not null'), 5);
  await assert.rejects(db.query(`update routes set is_public=false where id=$1`, [routeId]));
  await db.query(`update routes set description='Editada' where id=$1`, [routeId]);
  await db.query('delete from route_stops where route_id=$1 and position=0', [routeId]);
  await db.exec(seed);
  assert.equal(await scalar('select count(*) from businesses'), 51);
  assert.equal(await scalar('select count(*) from route_stops'), 57);
  assert.equal(await scalar(`select description from routes where id='${routeId}'`), 'Editada');
  assert.equal(await scalar(`select is_public from routes where id='${routeId}'`), true);
  console.log('OK segunda importación conserva ediciones y paradas eliminadas');

  await db.query(`update businesses set status='pendiente' where id='${other}'`);
  await assert.rejects(db.exec(seed), /no está publicado/);
  await db.exec('rollback');
  assert.equal(await scalar('select count(*) from route_stops'), 57);
  console.log('OK conflicto de publicación aborta toda la transacción');

  // Recreate the former account-linked original and verify the actual upgrade.
  await db.exec(`update routes set catalog_name=null,owner_id='${owner}' where id='${routeId}'`);
  await db.exec(globalMigration);
  assert.equal(await scalar(`select owner_id from routes where id='${routeId}'`), null);
  assert.equal(await scalar(`select description from routes where id='${routeId}'`), 'Editada');
  assert.equal(await scalar('select count(*) from route_stops'), 57);
  await db.exec(rlsMigration.slice(rlsMigration.indexOf('alter table public.routes enable'),
                                    rlsMigration.indexOf('-- ============ 6. reviews')));
  await db.exec(`
    grant usage on schema public,auth to anon,authenticated;
    grant select on routes,route_stops to anon;
    grant select,insert,update,delete on routes,route_stops to authenticated;
    set role anon;
  `);
  assert.equal(await scalar('select count(*) from routes'), 5);
  assert.equal(await scalar('select count(*) from route_stops'), 57);
  await db.exec(`reset role; set role authenticated; set test.user_id='${owner}';`);
  assert.equal(await scalar('select count(*) from routes'), 5);
  assert.equal((await db.query(`update routes set description='No autorizado' where id=$1 returning id`, [routeId])).rows.length, 0);
  assert.equal((await db.query('delete from route_stops where route_id=$1 returning id', [routeId])).rows.length, 0);
  await assert.rejects(db.query(`insert into routes(id,title,days,is_public,catalog_name)
    values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Otro circuito',1,true,'Ciudades Creativas')`), /row-level security/);
  // Copying a catalog remains a personal, private route that its owner can edit.
  await db.exec(`insert into routes(id,owner_id,title,days,is_public)
    values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','${owner}','Mi copia',1,false);`);
  await db.exec(`set test.is_admin='true';`);
  await db.exec(`insert into routes(id,title,days,is_public,catalog_name)
    values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Otro circuito',1,true,'Ciudades Creativas');`);
  await db.exec(`reset role; set test.is_admin='false'; set test.user_id=''; set role anon;`);
  assert.equal(await scalar('select count(*) from routes'), 6);
  assert.equal(await scalar(`select count(*) from routes where title='Mi copia'`), 0);
  await db.exec(`reset role; delete from routes where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';`);
  console.log('OK RLS: invitado y otras cuentas ven el catálogo, solo admin publica, copias privadas');
  await db.exec(`delete from profiles where id='${owner}'`);
  assert.equal(await scalar('select count(*) from routes where catalog_name is not null'), 5);
  assert.equal(await scalar(`select is_public from routes where id='${other}'`), false);
  console.log('OK migración preserva contenido y catálogo sobrevive a eliminar la cuenta promotora');
} finally {
  await db.close();
}
