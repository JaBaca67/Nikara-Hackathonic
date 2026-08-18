-- Nikara — diagnose + fix "MapScreen dice que no hay negocios" after the
-- 004 seed. Not applied automatically — same as 001-004, run by hand in the
-- Supabase dashboard: Project -> SQL Editor -> New query -> paste -> Run.
--
-- Run PART 1 first and read its output before touching PART 2 — it tells
-- you which of the two likely causes you actually have, so you don't
-- change the RLS posture of a table if that isn't even the problem:
--
--   A) The 004 script actually rolled back. It looked up
--      'dragonark08@gmail.com' — check that spelling against the request's
--      original 'dragonarc08@gmail.com' (arc vs ark). If that email had no
--      matching auth.users row, `raise exception` aborted the whole
--      transaction, and the DELETE+INSERT never committed — PART 1's
--      row count and owner emails below will show this immediately (either
--      0 rows, or the 3 old/expected rows are just missing).
--   B) The rows exist, but Row Level Security on `public.businesses` has
--      no SELECT policy for the anon/authenticated role the app queries
--      with. PostgREST returns 200 + `[]` in that case — not an error —
--      which is exactly why the client-side error overlay never showed
--      and the app fell through to the neutral "no hay negocios" empty
--      state instead. PART 1's `relrowsecurity`/policy list shows this.
--
-- Nothing in this app's code filters businesses by distance, is_active or
-- is_verified — BusinessStorageService._select() is a plain
-- `select().order('created_at')` with no .eq()/.rpc()/ST_DWithin call
-- anywhere, and MapScreen only filters the already-loaded list by category
-- and search text client-side. So an empty result can only come from
-- Supabase itself (A or B above), never from a client-side filter.


-- ============= PART 1: diagnose (read-only, changes nothing) =============

-- How many rows actually exist right now, and under which owner?
select id, owner_id, name, category, city, created_at
from public.businesses
order by created_at desc;

-- Does the seed's target account even exist, under either spelling?
select id, email from auth.users
where email in ('dragonarc08@gmail.com', 'dragonark08@gmail.com');

-- Is RLS enabled on businesses, and if so, does a SELECT policy exist for
-- anon/authenticated? An empty result set here (no rows at all) while RLS
-- shows `true` below is the strongest signal for cause B.
select relrowsecurity, relforcerowsecurity
from pg_class
where relname = 'businesses' and relnamespace = 'public'::regnamespace::oid;

select policyname, cmd, roles, qual
from pg_policies
where schemaname = 'public' and tablename = 'businesses';


-- ============= PART 2: fix — only run once PART 1 confirms cause B =======

-- This project's own documented design (see the doc comment on `anonKey`
-- in lib/core/supabase/supabase_config.dart) is that RLS is deliberately
-- disabled on tables like this one — access control happens client-side
-- (BusinessStorageService._requireOwnerId, the UI's own guard checks),
-- not via RLS policies, matching how `businesses` already behaves for
-- every other operation (insert/update/delete already work today with no
-- RLS policies backing them). So the fix consistent with that existing
-- design is to make sure RLS is OFF here — not to enable RLS and add only
-- a SELECT policy, which would leave insert/update/delete with no policy
-- at all and break the "Registra tu negocio" wizard instead.
--
-- Uncomment and run only after PART 1 confirms relrowsecurity = true here:

-- alter table public.businesses disable row level security;
