// Requiere la instalación local usada por validate_origin_migration.mjs.
import { PGlite } from '../build/origin_sql_validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated;
  create table profiles (id uuid, residence_type text, origin_country_code text, origin_city text, origin_municipality text);
  create table businesses (id integer primary key, name text, city text);
  create table eco_activities (id integer primary key, title text, location text);
  create table organizations (id integer primary key, name text);
  insert into businesses values (1,'Museo','La Trinidad'),(2,'Localidad','Miramar'),(3,'Ambiguo','Wiwilí'),(4,'Estelí','esteli');
  insert into eco_activities values (1,'Jornada','Parque central, La Trinidad'),(2,'Ambigua','Managua, Estelí'),(3,'Referencia','Camino a Estelí');
  grant usage on schema public to anon, authenticated;
  grant select, insert, update on businesses, eco_activities to authenticated;
  grant select, insert, update on organizations to authenticated;
`);
const catalog = readFileSync(new URL('../supabase/sql/041_origin_place_catalog.sql', import.meta.url), 'utf8');
await db.exec(catalog.slice(0, catalog.indexOf('-- Solo se usa')) + '\ncommit;');
const migration = readFileSync(new URL('../supabase/sql/042_discovery_geography.sql', import.meta.url), 'utf8');
await db.exec(migration);
await db.exec(migration);
const rows = async table => (await db.query(`select municipality_code from ${table} order by id`)).rows.map(row => row.municipality_code);
assert.deepEqual(await rows('businesses'), ['2525', null, null, '2515']);
assert.deepEqual(await rows('eco_activities'), ['2525', null, null]);
await db.exec('set role authenticated;');
await db.exec("insert into organizations values (1,'Fundación','2525');");
await assert.rejects(db.exec("insert into organizations values (2,'Inválida','9999')"), /foreign key/);
await assert.rejects(db.exec("insert into businesses values (5, 'Inventado', 'manguas', '9999')"), /foreign key/);
await db.exec("insert into businesses values (5,'Museo 2','la trinidad',null);");
await db.exec("update businesses set name='Editado' where id=2;");
await db.exec("update eco_activities set municipality_code='2525', location='Punto de encuentro' where id=1;");
assert.equal((await db.query('select municipality_code from eco_activities where id=1')).rows[0].municipality_code,'2525');
await db.exec("update eco_activities set location='Otra referencia', municipality_code='2525' where id=1;");
assert.equal((await db.query('select municipality_code from eco_activities where id=1')).rows[0].municipality_code,'2525');
assert.equal((await db.query('select municipality_code from businesses where id=5')).rows[0].municipality_code,'2525');
await db.close();
console.log('042: repetición, backfill conservador, FK, escritura autenticada y conservación del municipio: OK');
