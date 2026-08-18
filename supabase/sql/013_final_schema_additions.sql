-- Nikara — cierre de esquema para la fase de diagramación: avatar de
-- perfil, índices de auditoría sobre FKs que quedaron sin cubrir,
-- redirección de las FKs de identidad de usuario hacia `public.profiles`, y
-- las tres tablas finales del modelo (notifications, reviews,
-- user_favorites).
--
-- Not applied automatically — same as 001-012, run by hand in el Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run. Safe to
-- re-run (every statement is idempotent: `if not exists` / `create or
-- replace` en todos los casos).
--
-- RLS queda deshabilitada en las tres tablas nuevas, mismo criterio ya
-- usado en `businesses`, `eco_activities`, `organizations` y `routes` — ver
-- el comentario de `SupabaseConfig` en
-- lib/core/supabase/supabase_config.dart. La pertenencia (un usuario solo
-- ve/edita sus propias notificaciones, reseñas y favoritos) se valida en
-- Dart, en el servicio correspondiente — no en Postgres. `profiles` sigue
-- siendo la única tabla con RLS real (001_profiles_trigger_and_rls.sql),
-- porque ahí sí hay datos sensibles (email/teléfono) que un cliente no
-- debería poder leer o escribir libres de todo control.


-- ============ 1. Auditoría: columna faltante + índices de FK ==============

-- `profiles.avatar_url` no existía — `UserModel.initials` es hoy el único
-- fallback visual (ver su comentario en lib/core/models/user_model.dart)
-- precisamente porque no había dónde guardar una foto real. Opcional: nula
-- hasta que exista una pantalla de "editar foto de perfil" que la escriba;
-- este proyecto no usa object storage todavía, así que el valor esperado es
-- una URL http(s) o una ruta local de `image_picker`, mismo criterio que
-- `organizations.logo_url` / `routes.image_urls`.
alter table public.profiles
  add column if not exists avatar_url text;

-- Estas cuatro FKs ya existían sin índice de soporte — cada una es el lado
-- "muchos" de una relación que el propio Dart filtra hoy o va a filtrar
-- pronto ("Mis Negocios" en Perfil, jornadas creadas por un organizador,
-- paradas de ruta que referencian un negocio/jornada dado al borrarlo).
-- `organizations`/`routes` ya seguían este patrón desde 010/011; estas
-- cuatro quedaron atrás.
create index if not exists businesses_owner_id_idx
  on public.businesses (owner_id);
create index if not exists eco_activities_organizer_id_idx
  on public.eco_activities (organizer_id);
create index if not exists route_stops_business_id_idx
  on public.route_stops (business_id);
create index if not exists route_stops_eco_activity_id_idx
  on public.route_stops (eco_activity_id);

-- `businesses.owner_id`, `eco_activities.organizer_id` y
-- `eco_participants.user_id` apuntaban a `auth.users(id)` directamente (ver
-- 009_eco_activities.sql), mientras que `organizations.owner_id`,
-- `routes.owner_id` y las tres tablas nuevas de abajo apuntan a
-- `public.profiles(id)`. La sección 5 redirige esas tres FKs hacia
-- `public.profiles(id)` para que el 100% de las relaciones de identidad de
-- usuario en el esquema apunten a la misma entidad — ver esa sección para
-- el detalle de por qué es seguro (`profiles.id` es el mismo uuid que
-- `auth.users.id`, 1:1, por el trigger de 001_profiles_trigger_and_rls.sql,
-- así que no hay dato existente que quede huérfano).


-- ============ 2. notifications =============================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  -- Libre, misma convención que `businesses.category` / `routes.status`:
  -- distingue cómo navegar al tocar la notificación ("eco_join",
  -- "business_review", "route_shared", ...) sin necesitar una migración de
  -- tipo por cada variante nueva.
  type text not null,
  -- Id del recurso al que apunta la notificación (una jornada, un negocio,
  -- una reseña...) — polimórfico según `type`, así que no hay una sola
  -- tabla contra la que poner una FK real; mismo criterio que
  -- `route_stops.destination_id`. Ver la nota de "relaciones polimórficas"
  -- en docs/database_erd.md.
  reference_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_idx
  on public.notifications (user_id);
-- La consulta más común es "mis notificaciones sin leer, más recientes
-- primero" — índice parcial para que ese filtro no tenga que escanear las
-- ya leídas.
create index if not exists notifications_user_unread_idx
  on public.notifications (user_id, created_at desc)
  where not is_read;


-- ============ 3. reviews ====================================================

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- Igual que `notifications.reference_id`: `target_id` apunta a
  -- `businesses.id` o `eco_activities.id` según `target_type`, sin FK real
  -- porque una sola columna no puede referenciar dos tablas distintas.
  target_type text not null check (target_type in ('business', 'eco_activity')),
  target_id uuid not null,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists reviews_target_idx
  on public.reviews (target_type, target_id);
create index if not exists reviews_user_id_idx
  on public.reviews (user_id);


-- ============ 4. user_favorites =============================================

create table if not exists public.user_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_type text not null check (item_type in ('business', 'eco_activity', 'route')),
  item_id uuid not null,
  created_at timestamptz not null default now(),
  -- Un mismo usuario no puede favoritar el mismo ítem dos veces.
  constraint user_favorites_unique_item unique (user_id, item_type, item_id)
);

create index if not exists user_favorites_user_id_idx
  on public.user_favorites (user_id);


-- ============ 5. Redirección de FKs de identidad hacia `profiles` =========
--
-- Retarget, no un cambio de forma: cada bloque busca la FK que ya existe
-- sobre la columna (sea cual sea su nombre — `businesses` se creó fuera de
-- estos scripts, así que su constraint no tiene un nombre garantizado), y
-- solo actúa si esa FK todavía no apunta a `public.profiles`. Vuelve a
-- correr esto tantas veces como haga falta sin efecto duplicado: la segunda
-- vez, `v_target_table` ya es `profiles` y el bloque no hace nada.
--
-- El `on delete` de cada FK se preserva tal cual estaba (no se toca el
-- comportamiento, solo la tabla referenciada):
--   - `businesses.owner_id` — NOT NULL, sin `on delete` conocido porque la
--     tabla se creó fuera de estos scripts (dashboard); se deja en
--     `cascade`, igual que `organizations.owner_id` / `routes.owner_id`,
--     que son la misma relación "dueño NOT NULL" en el resto del esquema.
--   - `eco_activities.organizer_id` — se preserva `on delete set null`
--     (nullable, tal como quedó en 009_eco_activities.sql).
--   - `eco_participants.user_id` — se preserva `on delete cascade` (tal
--     como quedó en 009_eco_activities.sql).

do $$
declare
  v_constraint_name text;
  v_target_table text;
begin
  select con.conname, ref.relname
  into v_constraint_name, v_target_table
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  join pg_class ref on ref.oid = con.confrelid
  join pg_attribute att
    on att.attrelid = con.conrelid and att.attnum = con.conkey[1]
  where nsp.nspname = 'public'
    and rel.relname = 'businesses'
    and con.contype = 'f'
    and att.attname = 'owner_id';

  if v_target_table is distinct from 'profiles' then
    if v_constraint_name is not null then
      execute format('alter table public.businesses drop constraint %I', v_constraint_name);
    end if;
    execute
      'alter table public.businesses '
      || 'add constraint businesses_owner_id_fkey '
      || 'foreign key (owner_id) references public.profiles (id) on delete cascade';
  end if;
end $$;

do $$
declare
  v_constraint_name text;
  v_target_table text;
begin
  select con.conname, ref.relname
  into v_constraint_name, v_target_table
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  join pg_class ref on ref.oid = con.confrelid
  join pg_attribute att
    on att.attrelid = con.conrelid and att.attnum = con.conkey[1]
  where nsp.nspname = 'public'
    and rel.relname = 'eco_activities'
    and con.contype = 'f'
    and att.attname = 'organizer_id';

  if v_target_table is distinct from 'profiles' then
    if v_constraint_name is not null then
      execute format('alter table public.eco_activities drop constraint %I', v_constraint_name);
    end if;
    execute
      'alter table public.eco_activities '
      || 'add constraint eco_activities_organizer_id_fkey '
      || 'foreign key (organizer_id) references public.profiles (id) on delete set null';
  end if;
end $$;

do $$
declare
  v_constraint_name text;
  v_target_table text;
begin
  select con.conname, ref.relname
  into v_constraint_name, v_target_table
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  join pg_class ref on ref.oid = con.confrelid
  join pg_attribute att
    on att.attrelid = con.conrelid and att.attnum = con.conkey[1]
  where nsp.nspname = 'public'
    and rel.relname = 'eco_participants'
    and con.contype = 'f'
    and att.attname = 'user_id';

  if v_target_table is distinct from 'profiles' then
    if v_constraint_name is not null then
      execute format('alter table public.eco_participants drop constraint %I', v_constraint_name);
    end if;
    execute
      'alter table public.eco_participants '
      || 'add constraint eco_participants_user_id_fkey '
      || 'foreign key (user_id) references public.profiles (id) on delete cascade';
  end if;
end $$;
