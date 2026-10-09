-- Read-only. Run in Supabase SQL Editor after applying migration 049.
-- Never creates users, notifications or account content.

select table_name,column_name,data_type,column_default
from information_schema.columns
where table_schema='public' and (
 table_name in ('passport_trips','route_visit_progress','assistant_conversations')
 or (table_name='profiles' and column_name in ('username','trip_alerts','eco_campaigns','offers','public_profile'))
 or (table_name='businesses' and column_name='favorites_count')
) order by table_name,ordinal_position;

select tablename,policyname,cmd,roles,qual,with_check from pg_policies
where schemaname='public' and tablename in ('profiles','user_favorites','passport_trips','route_visit_progress','assistant_conversations')
order by tablename,policyname;

select tablename,rowsecurity from pg_tables
where schemaname='public' and tablename in ('profiles','user_favorites','passport_trips','route_visit_progress','assistant_conversations');

select p.proname,pg_get_function_identity_arguments(p.oid) as signature,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') as user_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in (
 'username_available','set_business_favorite','business_favorite_count','record_passport_trip',
 'refresh_business_favorites','guard_business_favorite_count','refresh_user_points','set_signup_username'
) order by p.proname;

select event_object_table,trigger_name,event_manipulation,action_timing
from information_schema.triggers where trigger_schema='public' and trigger_name in (
 'set_signup_username','validate_business_favorite','refresh_business_favorites',
 'remove_deleted_business_favorites','guard_business_favorite_count','refresh_points','respect_notification_preferences'
) order by event_object_table,trigger_name,event_manipulation;

select schemaname,tablename from pg_publication_tables where pubname='supabase_realtime'
order by schemaname,tablename;

select indexname,indexdef from pg_indexes where schemaname='public' and indexname in (
 'profiles_username_unique','favorites_business_count_idx','passport_trips_pkey','route_visit_progress_pkey'
);

-- Must return zero rows. This shows aggregate discrepancies, never identities
-- of users who favorited a business.
select b.id,b.favorites_count as stored_count,coalesce(f.actual_count,0) as actual_count
from public.businesses b left join (
 select item_id,count(distinct user_id) as actual_count from public.user_favorites
 where item_type='business' group by item_id
) f on f.item_id=b.id
where b.favorites_count<>coalesce(f.actual_count,0);

-- Column-level UPDATE grants for profiles must continue to exclude role/points.
select grantee,column_name,privilege_type from information_schema.column_privileges
where table_schema='public' and table_name='profiles' and grantee='authenticated' and privilege_type='UPDATE'
order by column_name;

select pg_get_viewdef('public.public_profiles'::regclass,true) as public_profile_view;
