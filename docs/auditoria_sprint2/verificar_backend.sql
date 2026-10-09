-- Níkara: diagnóstico para Sprint 2. Ejecutar en el SQL Editor del proyecto.
-- Solo SELECT dentro de una transacción READ ONLY. No modifica datos.
-- Devuelve metadatos y conteos; no devuelve correos, teléfonos, documentos,
-- tokens, secretos del webhook ni cuerpos de funciones.
begin transaction read only;

-- 1. RLS y cantidad de políticas. audit_logs sin políticas es intencional.
select c.relname as tabla, c.relrowsecurity as rls,
       count(p.oid) as politicas
from pg_class c join pg_namespace n on n.oid = c.relnamespace
left join pg_policy p on p.polrelid = c.oid
where n.nspname = 'public' and c.relkind = 'r'
group by c.relname, c.relrowsecurity order by c.relname;

-- 2. Condiciones reales de lectura y escritura. Comparar con el informe.
select tablename, policyname, roles, cmd, qual, with_check
from pg_policies where schemaname = 'public'
order by tablename, cmd, policyname;

-- 3. Privilegios sobre columnas sensibles. RLS no protege columnas por sí sola.
select c.table_name, c.column_name,
       has_column_privilege('authenticated',
         format('%I.%I', c.table_schema, c.table_name), c.column_name, 'INSERT') as auth_insert,
       has_column_privilege('authenticated',
         format('%I.%I', c.table_schema, c.table_name), c.column_name, 'UPDATE') as auth_update
from information_schema.columns c
where c.table_schema = 'public' and (
  (c.table_name = 'profiles' and c.column_name in ('role','points','full_name','phone','email'))
  or (c.table_name in ('businesses','organizations','eco_activities')
      and c.column_name in ('status','is_verified','reviewed_by','reviewed_at','rejection_reason'))
  or (c.table_name = 'legal_identities'
      and c.column_name in ('verified_by','verified_at'))
)
order by c.table_name, c.column_name;

-- 4. Triggers sin argumentos: tgargs del webhook podría contener un secreto.
select n.nspname as esquema, c.relname as tabla, t.tgname as trigger,
       t.tgenabled as habilitado, p.proname as funcion,
       ((t.tgtype::integer & 2) <> 0) as before_event,
       ((t.tgtype::integer & 4) <> 0) as on_insert,
       ((t.tgtype::integer & 8) <> 0) as on_delete,
       ((t.tgtype::integer & 16) <> 0) as on_update
from pg_trigger t join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal and n.nspname in ('public','auth')
order by n.nspname, c.relname, t.tgname;

-- 5. RPC existentes y permisos. Las funciones internas no deberían ser públicas.
select p.proname as funcion, pg_get_function_identity_arguments(p.oid) as argumentos,
       p.prosecdef as security_definer,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as auth_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in (
 'handle_new_user','is_admin','promote_to_emprendedor','delete_own_user',
 'review_business','review_organization','review_eco_activity',
 'notify_admins_of_pending_review','notify_eco_participation',
 'enable_user_notification_automations','sync_passport_notification_events',
 'run_notification_automations','get_eco_moment_state','set_eco_moment_policy',
 'eco_moment_state_for','eco_moment_manager','businesses_in_bounds',
 'guard_review_columns','guard_eco_moment_write','enforce_eco_capacity')
order by p.proname;

-- 6. Publicación de eventos. Tener la tabla no implica que emita eventos.
select pubname, schemaname, tablename from pg_publication_tables
where pubname = 'supabase_realtime' order by schemaname, tablename;

-- 7. Restricciones efectivas; permite revisar FK de copias, índices y CHECK.
select c.relname as tabla, con.conname as restriccion, con.contype as tipo,
       con.convalidated as validada, pg_get_constraintdef(con.oid) as definicion
from pg_constraint con join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in (
 'profiles','businesses','organizations','eco_activities','eco_participants',
 'routes','route_stops','reviews','user_favorites','legal_identities','audit_logs')
order by c.relname, con.conname;
select tablename, indexname, indexdef from pg_indexes
where schemaname = 'public' and tablename in ('reviews','route_stops','user_favorites')
order by tablename, indexname;

-- 8. Archivos: documentos privados, fotos públicas y políticas por dueño.
select id, public, file_size_limit, allowed_mime_types from storage.buckets order by id;
select policyname, roles, cmd, qual, with_check from pg_policies
where schemaname = 'storage' and tablename = 'objects' order by policyname;

-- 9. Consistencia de cuentas. Un alta correcta tiene perfil con el mismo UUID.
select
 (select count(*) from auth.users) as cuentas_auth,
 (select count(*) from public.profiles) as perfiles,
 (select count(*) from auth.users a left join public.profiles p on p.id=a.id
    where p.id is null) as cuentas_sin_perfil,
 (select count(*) from public.profiles p left join auth.users a on a.id=p.id
    where a.id is null) as perfiles_sin_cuenta;

-- 10. Filas parciales y referencias polimórficas sin destino real.
-- Una ruta vacía puede ser un borrador válido: revisar antes de clasificarla.
select count(*) as rutas_sin_paradas from public.routes r
where not exists (select 1 from public.route_stops s where s.route_id=r.id);
select count(*) as paradas_fuera_del_dia from public.route_stops s
join public.routes r on r.id=s.route_id where s.day_number > r.days;
select count(*) as favoritos_sin_destino from public.user_favorites f
where (f.item_type='business' and not exists (select 1 from public.businesses b where b.id=f.item_id))
   or (f.item_type='eco_activity' and not exists (select 1 from public.eco_activities a where a.id=f.item_id))
   or (f.item_type='route' and not exists (select 1 from public.routes r where r.id=f.item_id));
select count(*) as resenas_sin_destino from public.reviews v
where (v.target_type='business' and not exists (select 1 from public.businesses b where b.id=v.target_id))
   or (v.target_type='eco_activity' and not exists (select 1 from public.eco_activities a where a.id=v.target_id));
select count(*) as actividades_sobre_aforo from public.eco_activities a
where a.max_capacity is not null and
 (select count(*) from public.eco_participants p where p.activity_id=a.id)>a.max_capacity;
select count(*) as grupos_resenas_negocio_duplicadas from (
 select user_id,target_id from public.reviews where target_type='business'
 group by user_id,target_id having count(*)>1
) d;

-- 11. Datos públicos de la vista. No debe contener correo/teléfono/documento.
select column_name from information_schema.columns
where table_schema='public' and table_name='public_profiles' order by ordinal_position;

-- 12. Automatización: existencia de extensiones (el job se consulta aparte).
select extname, extversion from pg_extension where extname in ('pg_cron','pg_net','postgis');
select count(*) as usuarios_con_automatizacion,
       count(*) filter(where enabled) as usuarios_habilitados
from public.notification_automation_settings;

commit;

-- Ejecutar por separado SOLO si la sección 12 confirma pg_cron:
-- select jobname, schedule, active from cron.job
-- where jobname='nikara-notification-automations';
-- No ejecutar run_notification_automations() durante este diagnóstico:
-- sí inserta notificaciones y puede provocar push.
