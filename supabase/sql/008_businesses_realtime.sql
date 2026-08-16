-- Nikara — Realtime (live INSERT/UPDATE/DELETE) on `businesses`.
--
-- Not applied automatically — same as 001-007, run by hand in the Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run.
--
-- Why: MapScreen subscribes to row changes on `businesses`
-- (BusinessStorageService.subscribeToBusinessChanges) so a business
-- registered from another device/session shows up on the map without
-- reopening the screen. Supabase only streams changes for tables added to
-- the `supabase_realtime` publication — without this the subscription
-- still succeeds, it just never receives anything (the app keeps working
-- off its normal fetches, so this is an enhancement, not a requirement).
--
-- `replica identity full` makes DELETE events carry the whole old row
-- instead of only the primary key.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'businesses'
  ) then
    alter publication supabase_realtime add table public.businesses;
  end if;
end
$$;

alter table public.businesses replica identity full;
