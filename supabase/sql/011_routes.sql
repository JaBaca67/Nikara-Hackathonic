-- Nikara — módulo de Rutas: itinerarios por días armados con negocios,
-- actividades ECO y puntos turísticos.
--
-- Not applied automatically — same as 001-010, run by hand in the Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run. Safe to
-- re-run (every statement is idempotent).
--
-- RLS queda deshabilitada, igual que `businesses`, `eco_activities` y
-- `organizations` — ver el comentario de `SupabaseConfig` en
-- lib/core/supabase/supabase_config.dart. `RouteService` valida en Dart que
-- solo el dueño edite o borre su ruta, y que la copia de una ruta ajena
-- solo sea posible si es pública.

create table if not exists public.routes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  -- Cuántos días dura el itinerario. El tope de 30 es el mismo que impone
  -- el contador del wizard: evita que un valor absurdo genere 10 mil
  -- secciones de día en la pantalla de detalle.
  days integer not null default 1 check (days between 1 and 30),
  -- "Publicar en la comunidad" del paso 1. Una ruta pública es la que otra
  -- persona puede abrir y copiar a su propia cuenta.
  is_public boolean not null default false,
  -- Las dos pestañas pill de RoutesMainScreen. Texto con check en vez de
  -- un enum de Postgres, misma convención que `businesses.category`: un
  -- estado nuevo no necesita migración de tipo.
  status text not null default 'active' check (status in ('active', 'completed')),
  -- Procedencia cuando la ruta nació de "Copiar / Usar esta ruta". Se
  -- guarda para poder mostrar de dónde salió; `on delete set null` para que
  -- borrar el original no borre la copia.
  cloned_from_route_id uuid references public.routes (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.route_stops (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes (id) on delete cascade,
  -- 1..routes.days. No hay FK posible contra `days`, así que RouteService
  -- es quien garantiza que una parada nunca quede en un día que ya no
  -- existe (al bajar la duración reubica esas paradas al último día).
  day_number integer not null default 1 check (day_number >= 1),
  -- Orden dentro del día — lo que reordena el paso 3 del wizard.
  position integer not null default 0,
  -- 'business' | 'eco_activity' | 'destination'. Los puntos turísticos
  -- todavía no son una tabla (viven en mock_destinations.dart como dato
  -- estático del Inicio), por eso su id va en `destination_id` como texto
  -- suelto en lugar de una FK.
  kind text not null check (kind in ('business', 'eco_activity', 'destination')),
  business_id uuid references public.businesses (id) on delete set null,
  eco_activity_id uuid references public.eco_activities (id) on delete set null,
  destination_id text,
  -- Copia de los datos de la parada al momento de agregarla. Es
  -- deliberadamente denormalizado (misma decisión que
  -- `eco_activities.organizer_name`): un itinerario tiene que poder
  -- dibujarse completo con una sola consulta, sin depender de tres joins,
  -- y tiene que seguir leyéndose aunque el negocio o la jornada de origen
  -- se borren.
  title text not null,
  subtitle text not null default '',
  -- 'turistico' | 'eco' | 'gastronomico' — el chip de categoría de las
  -- tarjetas y del timeline.
  category text not null default 'turistico',
  image_path text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  -- Una misma parada no se repite dentro del mismo día; sí puede repetirse
  -- en días distintos (desayunar dos veces en el mismo lugar es válido).
  constraint route_stops_unique_per_day unique (route_id, day_number, kind, business_id, eco_activity_id, destination_id)
);

create index if not exists routes_owner_id_idx on public.routes (owner_id);
create index if not exists routes_public_idx on public.routes (is_public) where is_public;
create index if not exists route_stops_route_id_idx
  on public.route_stops (route_id, day_number, position);

-- Sin realtime a propósito (a diferencia de 008/009/010): una ruta es
-- material privado de una cuenta, y la pantalla ya se refresca sola con
-- `RouteService.revision` en el mismo dispositivo que la edita.
