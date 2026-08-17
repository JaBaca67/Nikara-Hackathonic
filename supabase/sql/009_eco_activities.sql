-- Nikara — ECO module: jornadas/actividades ambientales + participantes.
--
-- Not applied automatically — same as 001-008, run by hand in the Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run. Safe to
-- re-run (every statement is idempotent).
--
-- RLS is deliberately disabled here, same as `businesses` — see the
-- comment on `SupabaseConfig` in lib/core/supabase/supabase_config.dart
-- for why this project doesn't rely on it. `EcoService` validates
-- ownership (e.g. only an activity's own organizer could edit/delete it,
-- once that ships) in Dart instead.

create table if not exists public.eco_activities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  -- Free-text, same convention as `businesses.category` — validated
  -- against the fixed filter chip set ("Reforestación", "Fauna",
  -- "Limpieza", ...) app-side, not a Postgres enum, so a new category
  -- never needs a migration.
  category text not null,
  location text not null default '',
  latitude double precision,
  longitude double precision,
  start_time timestamptz not null,
  max_capacity integer,
  organizer_id uuid references auth.users (id) on delete set null,
  -- Denormalized beyond the plain organizer_id -> auth.users link: an
  -- activity's organizer is usually an organization ("Fundación
  -- Nicaragua Verde"), not a person with a `profiles` row, so there's no
  -- clean join target for its display name/verified badge. Nullable —
  -- EcoService falls back to a generic "Organizador" label when empty.
  organizer_name text,
  organizer_verified boolean not null default false,
  -- Not in the original column list the ECO module was specced with, but
  -- both the detail screen's "Requisitos y qué llevar" checklist and
  -- CreateEcoActivityScreen's "Requisitos" field need somewhere to read
  -- from/write to — a plain text array, same free-form-list spirit as
  -- `businesses.amenities`/`activities` (also arrays, no separate join
  -- table for a handful of short strings per row).
  requirements text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.eco_participants (
  activity_id uuid not null references public.eco_activities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (activity_id, user_id)
);

create index if not exists eco_activities_start_time_idx
  on public.eco_activities (start_time);
create index if not exists eco_participants_activity_id_idx
  on public.eco_participants (activity_id);
create index if not exists eco_participants_user_id_idx
  on public.eco_participants (user_id);

-- Realtime — same reasoning/pattern as 008_businesses_realtime.sql:
-- EcoService subscribes so a join/leave/new-activity from another
-- device shows up on EcoMainScreen without reopening the tab. Without
-- this the subscription still succeeds, it just never receives anything
-- (the app keeps working off its normal fetches).
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'eco_activities'
  ) then
    alter publication supabase_realtime add table public.eco_activities;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'eco_participants'
  ) then
    alter publication supabase_realtime add table public.eco_participants;
  end if;
end
$$;

alter table public.eco_activities replica identity full;
alter table public.eco_participants replica identity full;

-- Seed data — mirrors the "Actividades Ambientales" mock (Reforestación
-- Lago Cocibolca hero card, Fauna/Limpieza list rows) so EcoMainScreen has
-- something real to render immediately after this migration runs. Safe to
-- delete once real organizers start creating their own activities.
insert into public.eco_activities
  (title, description, category, location, latitude, longitude, start_time, max_capacity, organizer_name, organizer_verified, requirements)
select * from (values
  (
    'Reforestación Lago Cocibolca',
    'Plantamos árboles nativos en las orillas del gran lago para recuperar el ecosistema. Únete a esta jornada en las laderas para restaurar el ecosistema y prevenir la erosión del suelo.',
    'Reforestación',
    'Cerro Apante, Managua',
    12.1364::double precision,
    -86.2514::double precision,
    (now() + interval '3 days'),
    26,
    'Fundación Nicaragua Verde',
    true,
    array['Ropa cómoda y botas cerradas', 'Botella de agua y protector solar']
  ),
  (
    'Protección: Tortugas Paslama',
    'Vigilancia nocturna en La Flor y Chacocente para proteger los nidos de tortuga marina durante la temporada de desove.',
    'Fauna',
    'Refugio La Flor, Rivas',
    11.2167::double precision,
    -85.8500::double precision,
    (now() + interval '10 days'),
    15,
    'Voluntarios del Pacífico',
    false,
    array['Ropa oscura y repelente de insectos', 'Linterna con luz roja']
  ),
  (
    'Limpieza Reserva Indio Maíz',
    'Retiro de plásticos y residuos de los tributarios que alimentan la Reserva Biológica Indio Maíz.',
    'Limpieza',
    'Indio Maíz, Río San Juan',
    11.0500::double precision,
    -84.3500::double precision,
    (now() + interval '20 days'),
    40,
    'Comunidades Locales · MARENA',
    false,
    array['Guantes de jardinería', 'Botas de hule', 'Botella de agua']
  )
) as seed (title, description, category, location, latitude, longitude, start_time, max_capacity, organizer_name, organizer_verified, requirements)
where not exists (select 1 from public.eco_activities);
