-- Nikara — profiles: server-side creation trigger + RLS lockdown.
--
-- Not applied automatically — there's no service_role key or DB connection
-- available to Claude Code in this environment. Run this once, by hand, in
-- the Supabase dashboard: Project -> SQL Editor -> New query -> paste ->
-- Run. Safe to re-run (every statement is idempotent: `or replace`,
-- `if exists`, `if not exists`).
--
-- What this fixes:
--   1. `profiles` was created client-side (AuthService.signUp /
--      signInWithGoogle did a manual INSERT after auth.signUp()). If that
--      second call failed (dropped connection, app killed mid-flight), the
--      user ends up with an `auth.users` row and no `profiles` row —
--      permanently broken account, nothing in the app can recover it.
--   2. RLS was disabled on `profiles`. With the anon key (public, ships
--      inside the compiled app) and no RLS, any client can read every
--      user's email/phone, or write `UPDATE profiles SET role='admin'
--      WHERE id=...` directly against the REST API — full privilege
--      escalation, no server code involved.
-- Both are fixed by moving profile creation into a SECURITY DEFINER
-- trigger (runs with elevated privilege, independent of the client's
-- session state or RLS) and enabling RLS with policies that never let a
-- client set its own `role`.


-- 1. Auto-create the profiles row whenever a new auth.users row appears —
-- covers email/password signUp AND every OAuth provider (Google/Apple/
-- Facebook), since they all insert into auth.users the same way.
-- `security definer` + explicit `search_path` so this runs with the
-- function owner's privileges (bypassing RLS below) regardless of who/what
-- triggered it, and can't be hijacked by a `search_path` pointing at a
-- attacker-controlled schema.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    -- Always 'turista' regardless of what the client sent in signUp's
    -- `data:` metadata — never trust a client-supplied role, even at
    -- account-creation time.
    'turista'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- 2. Lock the table down.
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);
-- NOTE: this lets any signed-in user read any OTHER user's full_name,
-- email and phone (needed today for showing a business's real owner —
-- getProfileById() is called with arbitrary ids, not just the current
-- user's own). If that turns out to be broader than the app actually
-- needs, the fix is a narrower `public_profiles` view (id, full_name,
-- role only) instead of relaxing this policy further.

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);
-- No INSERT/DELETE policy for authenticated/anon at all — the only way a
-- row is created is the trigger above (which runs as the function owner,
-- not affected by RLS).

-- RLS is row-level, not column-level — a user with the update policy above
-- could otherwise set THEIR OWN role to 'admin'. Revoke the blanket UPDATE
-- grant Supabase applies by default and grant it back only on the columns
-- a user is allowed to change about themselves. `role` and `points` are
-- deliberately excluded.
revoke update on public.profiles from authenticated;
grant update (full_name, phone) on public.profiles to authenticated;


-- 3. The one legitimate client-triggered role change (turista ->
-- emprendedor, on registering a first business) goes through an RPC
-- instead of a direct UPDATE, so it's the ONLY role transition possible
-- from client code — never arbitrary, never to 'admin'/'auditor'.
create or replace function public.promote_to_emprendedor()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set role = 'emprendedor'
  where id = auth.uid() and role = 'turista';
end;
$$;

grant execute on function public.promote_to_emprendedor() to authenticated;
