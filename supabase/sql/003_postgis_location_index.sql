-- Nikara — PostGIS + spatial index on businesses.location.
--
-- Not applied automatically — same as 001/002, run this once by hand in the
-- Supabase dashboard: Project -> SQL Editor -> New query -> paste -> Run.
-- Safe to re-run (every statement below is idempotent).
--
-- Context: `businesses.location geography(Point,4326)` already exists and
-- is already the only geo column this app writes to or reads from — see
-- BusinessStorageService._toRow (writes `SRID=4326;POINT(lng lat)` EWKT
-- text into it on every insert/update) and ._parseLocation (reads it back
-- out on every fetch — GeoJSON, EWKT/WKT text or hex WKB, whichever
-- Postgres/PostgREST happens to hand back). There are no separate
-- `latitude`/`longitude`
-- columns on `businesses` in this schema for a location column to be
-- backfilled from — the DO block below only runs a backfill in the
-- hypothetical case those columns exist in the live database despite not
-- being referenced anywhere in this codebase (e.g. a manual dashboard
-- change), so this script is safe to run regardless of which case is true.
--
-- What this migration actually adds:
--   1. Makes sure the PostGIS extension is enabled (it must already be,
--      for `geography(Point,4326)` to exist at all — this is a no-op
--      confirmation, not a new capability).
--   2. A GiST spatial index on `location`, so a future "negocios cercanos"
--      radius query (`ST_DWithin(location, ST_MakePoint($lng,$lat)::geography, $meters)`)
--      doesn't do a full table scan as the table grows — nothing in the
--      client queries by distance yet, this just makes that cheap to add
--      later without another migration.

create extension if not exists postgis;

-- Defensive backfill: only runs if this database happens to have separate
-- latitude/longitude columns on businesses (it doesn't, per the current
-- BusinessStorageService — see note above). Guarded with information_schema
-- checks so this script never errors out on a schema that lacks them.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'businesses'
      and column_name = 'latitude'
  ) and exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'businesses'
      and column_name = 'longitude'
  ) then
    execute $sql$
      update public.businesses
      set location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
      where location is null and latitude is not null and longitude is not null
    $sql$;
  end if;
end $$;

create index if not exists businesses_location_gix
  on public.businesses using gist (location);
