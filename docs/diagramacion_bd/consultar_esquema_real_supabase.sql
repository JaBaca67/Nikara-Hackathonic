-- Inspección de esquema en modo de solo lectura. Ejecutar en el SQL Editor
-- del proyecto Supabase que se quiere verificar. No lee filas de usuarios.
-- Devuelve una sola fila y una columna JSONB para copiar como archivo JSON.
with objects as (
  select c.oid, n.nspname, c.relname, c.relkind
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p', 'v', 'm', 'f')
  union all
  select c.oid, n.nspname, c.relname, c.relkind
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'auth'
    and c.relname = 'users'
    and c.relkind in ('r', 'p')
),
relations as (
  select
    o.oid,
    jsonb_build_object(
      'schema', o.nspname,
      'name', o.relname,
      'kind', case o.relkind
        when 'r' then 'table'
        when 'p' then 'partitioned_table'
        when 'v' then 'view'
        when 'm' then 'materialized_view'
        when 'f' then 'foreign_table'
        else o.relkind::text
      end,
      'columns', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'name', a.attname,
          'type', pg_catalog.format_type(a.atttypid, a.atttypmod),
          'nullable', not a.attnotnull,
          'default', pg_catalog.pg_get_expr(d.adbin, d.adrelid)
        ) order by a.attnum), '[]'::jsonb)
        from pg_catalog.pg_attribute a
        left join pg_catalog.pg_attrdef d
          on d.adrelid = a.attrelid and d.adnum = a.attnum
        where a.attrelid = o.oid
          and a.attnum > 0
          and not a.attisdropped
          and (o.nspname <> 'auth' or a.attname = 'id')
      ),
      'keys', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'kind', case con.contype when 'p' then 'primary' else 'unique' end,
          'name', con.conname,
          'columns', (
            select jsonb_agg(a.attname order by k.ordinality)
            from unnest(con.conkey) with ordinality as k(attnum, ordinality)
            join pg_catalog.pg_attribute a
              on a.attrelid = con.conrelid and a.attnum = k.attnum
          )
        ) order by con.conname), '[]'::jsonb)
        from pg_catalog.pg_constraint con
        where con.conrelid = o.oid and con.contype in ('p', 'u')
      ),
      'foreign_keys', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'name', con.conname,
          'columns', (
            select jsonb_agg(a.attname order by k.ordinality)
            from unnest(con.conkey) with ordinality as k(attnum, ordinality)
            join pg_catalog.pg_attribute a
              on a.attrelid = con.conrelid and a.attnum = k.attnum
          ),
          'references_schema', parent_ns.nspname,
          'references_table', parent.relname,
          'references_columns', (
            select jsonb_agg(a.attname order by k.ordinality)
            from unnest(con.confkey) with ordinality as k(attnum, ordinality)
            join pg_catalog.pg_attribute a
              on a.attrelid = con.confrelid and a.attnum = k.attnum
          ),
          'on_delete', case con.confdeltype
            when 'a' then 'no_action' when 'r' then 'restrict'
            when 'c' then 'cascade' when 'n' then 'set_null'
            when 'd' then 'set_default' else con.confdeltype::text
          end,
          'validated', con.convalidated
        ) order by con.conname), '[]'::jsonb)
        from pg_catalog.pg_constraint con
        join pg_catalog.pg_class parent on parent.oid = con.confrelid
        join pg_catalog.pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
        where con.conrelid = o.oid and con.contype = 'f'
      )
    ) as definition
  from objects o
)
select jsonb_pretty(jsonb_build_object(
  'source', current_database(),
  'captured_at', transaction_timestamp(),
  'relations', coalesce((
    select jsonb_agg(definition order by definition->>'schema', definition->>'name')
    from relations
  ), '[]'::jsonb),
  'public_enums', coalesce((
    select jsonb_agg(jsonb_build_object(
      'schema', n.nspname,
      'name', t.typname,
      'values', (select jsonb_agg(e.enumlabel order by e.enumsortorder)
                 from pg_catalog.pg_enum e where e.enumtypid = t.oid)
    ) order by t.typname)
    from pg_catalog.pg_type t
    join pg_catalog.pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typtype = 'e'
  ), '[]'::jsonb)
)) as supabase_schema_snapshot;
