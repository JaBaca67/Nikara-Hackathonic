-- Nikara — viewport-scoped business queries for MapScreen.
--
-- Not applied automatically — same as 001-006, run by hand in the Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run. Safe to
-- re-run (`create or replace`).
--
-- Why: BusinessStorageService.getBusinesses() loads every row in
-- `businesses` on every MapScreen open — fine at prototype scale (a
-- handful of rows), but it doesn't scale: the map would be re-downloading
-- (and re-parsing, re-clustering) the entire business table on every
-- screen open regardless of what's actually visible. This RPC lets the
-- client ask only for what's in the current camera viewport, using the
-- GiST index 003 already added on `location` via the `&&` bounding-box
-- operator (index-accelerated — this is the standard PostGIS idiom for a
-- map viewport query, not a full geometric ST_Intersects test, since
-- pins slightly outside the exact viewport edge are harmless here).
create or replace function public.businesses_in_bounds(
  min_lng double precision,
  min_lat double precision,
  max_lng double precision,
  max_lat double precision
)
returns setof public.businesses
language sql
stable
as $$
  select *
  from public.businesses
  where location && ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
$$;

grant execute on function public.businesses_in_bounds to anon, authenticated;
