-- Nikara — ECO module: organizaciones (fundaciones) y publicación en su
-- nombre ("context switching" al crear una jornada).
--
-- Not applied automatically — same as 001-009, run by hand in the Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run. Safe to
-- re-run (every statement is idempotent).
--
-- IMPORTANTE: hasta que esta migración corra, `eco_activities` no tiene la
-- columna `organization_id` ni existe la relación que EcoService intenta
-- embeber. El feed ECO sigue funcionando igual (EcoService detecta que la
-- relación no existe y repite la consulta sin ella), pero nada se publica
-- en nombre de una fundación hasta correrla.
--
-- RLS queda deshabilitada, igual que `businesses` y `eco_activities` — ver
-- el comentario de `SupabaseConfig` en lib/core/supabase/supabase_config.dart
-- para el porqué. La pertenencia (solo el dueño gestiona su fundación) se
-- valida en Dart, en `OrganizationService`.

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- Identificador público corto, sin la arroba y en minúsculas
  -- ("cocibolcavive"). La app lo normaliza antes de insertar y lo muestra
  -- como "@cocibolcavive".
  handle text not null unique,
  description text not null default '',
  -- Igual que `businesses.photos`: pueden ser una URL http(s) o la ruta
  -- local de una imagen elegida con image_picker — este proyecto todavía no
  -- usa object storage, y `LocalImage` resuelve ambos casos.
  logo_url text,
  banner_url text,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  -- Arranca en `true` a propósito para esta fase de prueba: todavía no hay
  -- flujo de auditoría de fundaciones. Es lo contrario de
  -- `businesses.is_verified` (que solo un auditor pone en true), así que
  -- cuando ese flujo exista hay que bajar este default a `false`.
  is_verified boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists organizations_owner_id_idx
  on public.organizations (owner_id);

-- Una actividad sin `organization_id` la publica una persona a título
-- personal (se muestra su nombre y foto de perfil); con valor, la publica
-- esa fundación (logo, nombre y badge VERIFICADO). `on delete set null`
-- para que borrar la fundación no borre el historial de jornadas.
alter table public.eco_activities
  add column if not exists organization_id uuid
  references public.organizations (id) on delete set null;

create index if not exists eco_activities_organization_id_idx
  on public.eco_activities (organization_id);

-- Realtime — mismo criterio que 008/009: crear o editar una fundación
-- desde otro dispositivo se refleja sin reabrir la pestaña.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'organizations'
  ) then
    alter publication supabase_realtime add table public.organizations;
  end if;
end
$$;

alter table public.organizations replica identity full;
