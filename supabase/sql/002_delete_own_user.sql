-- Nikara — self-service account deletion.
--
-- Not applied automatically — same as 001_profiles_trigger_and_rls.sql, run
-- this once by hand in the Supabase dashboard: Project -> SQL Editor -> New
-- query -> paste -> Run. Safe to re-run (`create or replace`).
--
-- Deleting from `auth.users` needs privileges no client-side role has (the
-- `authenticated` role PostgREST uses never gets DELETE on the `auth`
-- schema) — `security definer` runs this with the function owner's
-- privileges instead, but the WHERE clause is hardcoded to `auth.uid()`, so
-- a caller can only ever delete their OWN row, never anyone else's.
--
-- `public.profiles` is deleted explicitly here rather than assumed to
-- cascade from an `on delete cascade` FK on `auth.users` — if that FK
-- exists this is just a harmless no-op second delete, but if it doesn't
-- (or gets changed later) the profile row would otherwise survive as an
-- orphan with no matching auth user, which is exactly the leftover data
-- this function exists to prevent.
create or replace function public.delete_own_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.profiles where id = auth.uid();
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_own_user() to authenticated;
