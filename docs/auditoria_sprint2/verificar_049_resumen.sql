-- Solo lectura. Ejecutar en el SQL Editor del proyecto después de 049.
-- Devuelve UN resultado exportable a CSV: control, estado y detalle.
-- Comprueba instalación e integridad actual, no sustituye pruebas con sesiones.
with controles as (
 select '01 Columnas del perfil' as control,
  count(*)=5 as cumple,
  count(*)::text || '/5 columnas encontradas' as detalle
 from information_schema.columns where table_schema='public' and table_name='profiles'
 and column_name in ('username','trip_alerts','eco_campaigns','offers','public_profile')
 union all
 select '02 Columna del contador',count(*)=1,count(*)::text || '/1 columna encontrada'
 from information_schema.columns where table_schema='public' and table_name='businesses' and column_name='favorites_count'
 union all
 select '03 Tablas privadas nuevas',count(*)=3,count(*)::text || '/3 tablas con RLS'
 from pg_catalog.pg_tables where schemaname='public'
 and tablename in ('passport_trips','route_visit_progress','assistant_conversations') and rowsecurity
 union all
 select '04 RLS de perfiles y favoritos',count(*)=2,count(*)::text || '/2 tablas con RLS'
 from pg_catalog.pg_tables where schemaname='public' and tablename in ('profiles','user_favorites') and rowsecurity
 union all
 select '05 Políticas privadas nuevas',count(*)=3,count(*)::text || '/3 políticas propias encontradas'
 from pg_catalog.pg_policies where schemaname='public' and (tablename,policyname) in (
  ('passport_trips','passport_trips_own_read'),
  ('route_visit_progress','route_visit_progress_own'),
  ('assistant_conversations','assistant_conversations_own'))
 and roles=array['authenticated']::name[] and qual like '%auth.uid()%'
 union all
 select '06 Unicidad del username',count(*)=1,count(*)::text || '/1 índice único encontrado'
 from pg_catalog.pg_indexes where schemaname='public' and indexname='profiles_username_unique'
 and indexdef like 'CREATE UNIQUE INDEX%'
 union all
 select '07 Permisos de RPC de clientes',count(*)=4,count(*)::text || '/4 funciones con permisos esperados'
 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.oid in (
  to_regprocedure('public.username_available(text)'),
  to_regprocedure('public.set_business_favorite(uuid,boolean)'),
  to_regprocedure('public.business_favorite_count(uuid)'),
  to_regprocedure('public.record_passport_trip(text,uuid,timestamptz,timestamptz)'))
 and p.prosecdef and has_function_privilege('authenticated',p.oid,'EXECUTE')
 and has_function_privilege('anon',p.oid,'EXECUTE')=(p.proname='username_available')
 union all
 select '08 Función interna de puntos protegida',count(*)=1,count(*)::text || '/1 función sin acceso de clientes'
 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.oid=to_regprocedure('public.refresh_user_points(uuid)')
 and not has_function_privilege('authenticated',p.oid,'EXECUTE')
 and not has_function_privilege('anon',p.oid,'EXECUTE')
 union all
 select '09 Triggers de 049',count(*)=9,count(*)::text || '/9 triggers habilitados'
 from pg_catalog.pg_trigger t
 join pg_catalog.pg_class c on c.oid=t.tgrelid
 join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and not t.tgisinternal and t.tgenabled in ('O','A')
 and (c.relname,t.tgname) in (
  ('profiles','set_signup_username'),('user_favorites','validate_business_favorite'),
  ('user_favorites','refresh_business_favorites'),('businesses','remove_deleted_business_favorites'),
  ('businesses','guard_business_favorite_count'),('passport_trips','refresh_points'),
  ('user_favorites','refresh_points'),('reviews','refresh_points'),
  ('notifications','respect_notification_preferences'))
 union all
 select '10 Publicación Realtime',count(*)=14,count(*)::text || '/14 tablas publicadas'
 from pg_catalog.pg_publication_tables where pubname='supabase_realtime' and schemaname='public'
 and tablename in ('businesses','reviews','routes','eco_activities','eco_participants','organizations',
  'user_favorites','passport_trips','route_visit_progress','assistant_conversations','profiles',
  'route_stops','business_posts','notifications')
 union all
 select '11 Contador de favoritos coherente',count(*)=0,count(*)::text || ' negocios con discrepancias'
 from public.businesses b where b.favorites_count is distinct from (
  select count(distinct f.user_id) from public.user_favorites f where f.item_type='business' and f.item_id=b.id)
 union all
 select '12 Puntos coherentes',count(*)=0,count(*)::text || ' perfiles con discrepancias'
 from public.profiles p where p.points is distinct from (
  100*(select count(*) from public.passport_trips t where t.user_id=p.id)
  +15*(select count(*) from public.user_favorites f where f.user_id=p.id and f.item_type='business')
  +20*(select count(*) from public.reviews r where r.user_id=p.id and r.target_type='business'))
 union all
 select '13 Vista pública con username',count(*)=1,count(*)::text || '/1 columna encontrada'
 from information_schema.columns where table_schema='public' and table_name='public_profiles' and column_name='username'
 union all
 select '14 Sin edición directa de rol o puntos',count(*)=0,count(*)::text || ' permisos de edición indebidos'
 from information_schema.column_privileges where table_schema='public' and table_name='profiles'
 and grantee='authenticated' and privilege_type='UPDATE' and column_name in ('role','points')
)
select control,case when cumple then 'OK' else 'REVISAR' end as estado,detalle
from controles order by control;
