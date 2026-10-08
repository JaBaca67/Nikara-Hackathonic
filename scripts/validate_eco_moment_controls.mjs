// npm install --prefix build/origin_sql_validation @electric-sql/pglite
// node scripts/validate_eco_moment_controls.mjs
import { PGlite } from '../build/origin_sql_validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
await db.exec(`
create role anon; create role authenticated; create schema auth;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table public.profiles(id uuid primary key,role text);
create table public.organizations(id uuid primary key,owner_id uuid);
create table public.eco_activities(id uuid primary key,organizer_id uuid,organization_id uuid,status text);
create table public.eco_participants(activity_id uuid,user_id uuid,primary key(activity_id,user_id));
create table public.reviews(id uuid primary key default gen_random_uuid(),user_id uuid,target_id uuid,target_type text,comment text default '');
grant usage on schema public,auth to authenticated,anon;
grant select,insert,update,delete on public.reviews to authenticated;
alter table public.reviews enable row level security;
create policy read_reviews on reviews for select using(true);
create policy insert_reviews on reviews for insert with check(user_id=auth.uid());
create policy update_reviews on reviews for update using(user_id=auth.uid()) with check(user_id=auth.uid());
insert into profiles values ('${id(1)}','emprendedor'),('${id(2)}','emprendedor'),('${id(3)}','turista'),('${id(4)}','turista'),('${id(5)}','turista'),('${id(6)}','admin'),('${id(7)}','turista');
insert into organizations values('${id(20)}','${id(2)}');
insert into eco_activities values('${id(30)}','${id(1)}','${id(20)}','aprobado');
insert into eco_participants values('${id(30)}','${id(3)}'),('${id(30)}','${id(4)}'),('${id(30)}','${id(5)}');
`);
const migration = readFileSync(new URL('../supabase/sql/043_eco_moment_controls.sql',import.meta.url),'utf8');
await db.exec(migration); await db.exec(migration);
const login = async n => db.exec(`reset role; set request.jwt.claim.sub='${n ? id(n):''}'; set role authenticated;`);
const state = async () => (await db.query('select public.get_eco_moment_state($1) as state',[id(30)])).rows[0].state;
const policy = async (enabled,messages=null,accounts=null,perAccount=null) => db.query('select public.set_eco_moment_policy($1,$2,$3,$4,$5)',[id(30),enabled,messages,accounts,perAccount]);
const post = async (n,type='eco_activity',target=id(30)) => db.query('insert into reviews(user_id,target_type,target_id) values($1,$2,$3) returning id',[id(n),type,target]);
await login(3);
assert.equal((await state()).can_post,true);
await assert.rejects(policy(false),/Solo quien administra/);
await assert.rejects(post(4),/row-level security/);
await login(7); await assert.rejects(post(7),/Únete a la actividad/);
await login(1); await assert.rejects(policy(true,0),/mayores que cero/);
await policy(false);
await login(3); await assert.rejects(post(3),/cerrado/);
await login(2); assert.equal((await state()).can_manage,true); await post(2); // propietario de fundación
await login(6); await post(6); // admin plataforma, sin inscripción
await login(1); await post(1); await policy(true,3,2,2);
await login(3); const first=(await post(3)).rows[0].id; await post(3);
await assert.rejects(post(3),/por cuenta/);
await db.query('update reviews set comment=$1 where id=$2',['Mensaje editado',first]);
await assert.rejects(db.query('update reviews set target_type=$1 where id=$2',['business',first]),/autor ni el destino/);
await login(4); await post(4);
await assert.rejects(post(4),/límite de mensajes/);
await login(1); await policy(true,null,2,null);
await login(5); await assert.rejects(post(5),/límite de cuentas/);
await login(3); await post(3); // una cuenta existente conserva su cupo
assert.equal((await state()).account_count,2);
assert.equal((await state()).message_count,4); // administradores excluidos
await login(5); const business=(await post(5,'business',id(40))).rows[0].id;
await assert.rejects(db.query('update reviews set target_type=$1,target_id=$2 where id=$3',['eco_activity',id(30),business]),/autor ni el destino/);
await login(1); await policy(false,1,1,1);
await login(3); await assert.rejects(db.query('update reviews set comment=$1 where id=$2',['Edición tras cierre',first]),/cerrado/);
await assert.rejects(db.query('select public.eco_moment_state_for($1,$2)',[id(30),id(1)]),/permission denied/);
await login(null); await assert.rejects(state(),/Inicia sesión/);
await db.exec('reset role; set role anon;');
await assert.rejects(state(),/permission denied/);
await assert.rejects(policy(true),/permission denied/);
await db.exec('reset role;');
await db.exec("update eco_activities set status='pendiente'");
await login(1); assert.equal((await state()).can_manage,true); assert.equal((await state()).can_post,false);
await assert.rejects(post(1),/todavía no está publicada/);
await db.exec('reset role;');
assert.equal((await db.query("select provolatile from pg_proc where proname='eco_moment_state_for'")).rows[0].provolatile,'v');
// Snapshot renovado después de FOR UPDATE: necesario para cupos concurrentes.
await assert.rejects(db.exec('update eco_activities set moments_max_accounts=-1'),/eco_moments_positive_limits/);
await db.close();
console.log('Momentos: cierre, cupos, cuentas, permisos, autoría, edición, RPC y migración repetible: OK');
