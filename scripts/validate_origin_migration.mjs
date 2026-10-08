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

// 041 conserva texto histórico sin inventar lugares y protege nuevas escrituras.
const legacyOrigin = await scalar("select origin_city, origin_municipality from profiles where id='11111111-1111-4111-8111-111111111111'");
for (const [id, city, municipality] of [
  ['55555555-5555-4555-8555-555555555555', ' nindiri ', ' NINDIRI '],
  ['66666666-6666-4666-8666-666666666666', 'Wiwilí', 'Wiwilí'],
]) {
  await db.query('insert into auth.users values ($1,$2,$3,$4)', [
    id, `${id}@example.com`,
    { residence_type: 'nicaraguan', origin_country_code: 'NI', origin_city: city, origin_municipality: municipality },
    { provider: 'email' },
  ]);
}
const catalogMigration = readFileSync(new URL('../supabase/sql/041_origin_place_catalog.sql', import.meta.url), 'utf8');
await db.exec(catalogMigration);
await db.exec(catalogMigration);
assert.deepEqual(await scalar("select origin_city, origin_municipality from profiles where id='11111111-1111-4111-8111-111111111111'"), legacyOrigin);
assert.deepEqual(await scalar("select origin_city, origin_municipality from profiles where id='55555555-5555-4555-8555-555555555555'"), {origin_city: 'Nindirí', origin_municipality: 'Nindirí'});
assert.deepEqual(await scalar("select origin_city, origin_municipality from profiles where id='66666666-6666-4666-8666-666666666666'"), {origin_city: 'Wiwilí', origin_municipality: 'Wiwilí'});

// Compara el catálogo embarcado en Flutter con los valores de Postgres.
const dartCatalog = readFileSync(new URL('../lib/core/models/nicaragua_origin_places.dart', import.meta.url), 'utf8');
const places = [...dartCatalog.matchAll(/NicaraguaOriginPlace\(\s*'(\d{4})',\s*'([^']+)',\s*'([^']+)'(?:,\s*city:\s*'([^']+)')?/g)]
  .map(([, municipality_code, department, municipality, city]) => ({municipality_code, department, municipality, city: city ?? municipality}))
  .sort((a, b) => a.municipality_code.localeCompare(b.municipality_code));
assert.equal(places.length, 153);
assert.deepEqual((await db.query('select municipality_code, department, municipality, city from origin_places order by municipality_code')).rows, places);

await db.exec('set role anon;');
assert.equal((await scalar('select count(*)::integer as count from origin_places')).count, 153);
await assert.rejects(db.exec("insert into origin_places values ('9999','X','X','X','{}')"), /permission denied/);
await db.exec('reset role; set role authenticated;');
await db.exec("update profiles set bio='Los datos antiguos no bloquean cambios ajenos al origen' where id=auth.uid()");
await assert.rejects(db.exec("update origin_places set city='Inventada' where municipality_code='6010'"), /permission denied/);
await assert.rejects(db.exec("update profiles set origin_city='Inventada', origin_municipality='Inventado' where id=auth.uid()"), /profiles_origin_place_catalog/);
await assert.rejects(db.exec("update profiles set origin_city='Masaya', origin_municipality='Nindirí' where id=auth.uid()"), /profiles_origin_place_catalog/);
await assert.rejects(db.exec("update profiles set origin_city='nindiri', origin_municipality='nindiri' where id=auth.uid()"), /profiles_origin_place_catalog/);
await db.exec("update profiles set origin_city='Malpaisillo', origin_municipality='Larreynaga' where id=auth.uid();");
await db.exec("update profiles set residence_type='foreign', origin_country_code='ES', origin_city=null, origin_municipality=null where id=auth.uid();");
await db.exec('reset role;');
await assert.rejects(db.query('insert into auth.users values ($1,$2,$3,$4)', [
  '77777777-7777-4777-8777-777777777777', 'invalid-place@example.com',
  { residence_type: 'nicaraguan', origin_country_code: 'NI', origin_city: 'Inventada', origin_municipality: 'Inventado' },
  { provider: 'email' },
]), /profiles_origin_place_catalog/);
assert.equal((await scalar("select count(*)::integer as count from auth.users where email='invalid-place@example.com'")).count, 0);
await db.query('insert into auth.users values ($1,$2,$3,$4)', [
  '88888888-8888-4888-8888-888888888888', 'bilwi@example.com',
  { residence_type: 'nicaraguan', origin_country_code: 'NI', origin_city: 'Bilwi', origin_municipality: 'Puerto Cabezas' },
  { provider: 'email' },
]);
await db.close();
console.log('SQL validado: 039 y 041 repetibles, catálogo idéntico a Flutter, registro/Google, claves foráneas, datos históricos, RLS, grants y privacidad.');
