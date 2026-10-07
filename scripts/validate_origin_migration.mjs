// npm install --prefix build/origin_sql_validation @electric-sql/pglite
// node scripts/validate_origin_migration.mjs
import { PGlite } from '../build/origin_sql_validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
await db.exec(`
  create role anon;
  create role authenticated;
  create schema auth;
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  create table auth.users (
    id uuid primary key, email text, raw_user_meta_data jsonb default '{}',
    raw_app_meta_data jsonb default '{}'
  );
  create table public.profiles (
    id uuid primary key references auth.users(id), full_name text, email text,
    phone text, avatar_url text, role text default 'turista', points integer default 0
  );
  create view public.public_profiles as select id, full_name, avatar_url, role, points from public.profiles;
  insert into auth.users (id, email) values ('11111111-1111-4111-8111-111111111111', 'legacy@example.com');
  insert into profiles (id, full_name, email) values ('11111111-1111-4111-8111-111111111111', 'Ana Pérez', 'legacy@example.com');
  alter table profiles enable row level security;
  create policy profiles_select_own on profiles for select to authenticated using (id = auth.uid());
  create policy profiles_update_own on profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
  grant usage on schema public, auth to anon, authenticated;
  grant select on profiles to authenticated;
  grant update (full_name, phone, avatar_url) on profiles to authenticated;
`);
const migration = readFileSync(new URL('../supabase/sql/039_user_origin_and_public_profile.sql', import.meta.url), 'utf8');
await db.exec(migration);
await db.exec(migration);
await db.exec('create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user()');

const scalar = async (sql, params) => (await db.query(sql, params)).rows[0];
assert.equal((await scalar('select residence_type from profiles')).residence_type, null);
for (const [residence, country, city, municipality, valid] of [
  ['nicaraguan', 'NI', 'Masaya', 'Nindirí', true],
  ['nicaraguan', 'NI', null, 'Nindirí', false],
  ['nicaraguan', 'NI', ' ', 'Nindirí', false],
  ['nicaraguan', 'NI', 'Masaya', null, false],
  ['foreign', 'US', null, null, true],
  ['foreign', 'NI', null, null, false],
  ['foreign', 'ZZ', null, null, false],
  [null, 'US', null, null, false],
  ['foreign', 'US', 'Masaya', null, false],
]) {
  assert.equal((await scalar('select public.is_valid_user_origin($1,$2,$3,$4) as valid', [residence, country, city, municipality])).valid, valid);
}
await db.query("insert into auth.users values ($1,$2,$3,$4)", [
  '22222222-2222-4222-8222-222222222222', 'new@example.com',
  { full_name: 'John', role: 'admin', residence_type: 'foreign', origin_country_code: 'US' },
  { provider: 'email' },
]);
assert.deepEqual(await scalar("select role, origin_country_code from profiles where full_name='John'"), {role: 'turista', origin_country_code: 'US'});
await assert.rejects(db.query('insert into auth.users values ($1,$2,$3,$4)', [
  '33333333-3333-4333-8333-333333333333', 'invalid@example.com', {}, {provider: 'email'},
]), /Completa tu procedencia/);
await db.query('insert into auth.users values ($1,$2,$3,$4)', [
  '44444444-4444-4444-8444-444444444444', 'oauth@example.com', {}, {provider: 'google'},
]);
assert.equal((await scalar("select residence_type from profiles where email='oauth@example.com'")).residence_type, null);

await db.exec("set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111'; set role authenticated;");
await db.exec("update profiles set residence_type='nicaraguan', origin_country_code='NI', origin_city='Masaya', origin_municipality='Nindirí', public_display_name='Viajera', bio='Exploro Nicaragua' where id=auth.uid();");
assert.equal((await scalar('select count(*)::integer as count from profiles')).count, 1);
assert.equal((await db.query("update profiles set bio='No autorizado' where id='22222222-2222-4222-8222-222222222222' returning id")).rows.length, 0);
await assert.rejects(db.exec("update profiles set role='admin' where id=auth.uid()"), /permission denied/);
await assert.rejects(db.exec("update profiles set origin_municipality=null where id=auth.uid()"), /profiles_origin_valid/);
await assert.rejects(db.query('update profiles set bio=$1 where id=auth.uid()', ['x'.repeat(301)]), /profiles_public_text_lengths/);
await db.exec('update profiles set show_origin_details=false where id=auth.uid(); reset role; set role anon;');
assert.deepEqual(await scalar("select full_name, origin_country_code, origin_city, origin_municipality from public_profiles where full_name='Viajera'"), {full_name:'Viajera', origin_country_code:'NI', origin_city:null, origin_municipality:null});
await assert.rejects(db.exec('select email from public_profiles'), /does not exist/);
await assert.rejects(db.exec('select * from profiles'), /permission denied/);
await db.exec("reset role; set role authenticated; update profiles set show_origin=false where id=auth.uid(); reset role; set role anon;");
assert.deepEqual(await scalar("select residence_type, origin_country_code, origin_city, origin_municipality from public_profiles where full_name='Viajera'"), {residence_type:null, origin_country_code:null, origin_city:null, origin_municipality:null});
await db.exec('reset role');
assert.equal((await scalar("select origin_city from profiles where id='11111111-1111-4111-8111-111111111111'")).origin_city, 'Masaya');
await db.close();
console.log('SQL validado: migración repetible, registro/Google, validaciones, RLS, grants y privacidad pública.');
