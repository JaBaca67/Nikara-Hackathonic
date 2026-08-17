-- Nikara — módulo de Rutas: fotos de portada personalizadas.
--
-- Not applied automatically — same as 001-011, run by hand in the Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run. Safe to
-- re-run (every statement is idempotent).
--
-- No hace falta tocar el embed de `profiles` para la pestaña Comunidad:
-- `routes.owner_id references public.profiles (id)` ya existe desde
-- 011_routes.sql, así que RouteService ya puede pedir
-- `profiles(id, full_name)` sin ninguna migración adicional.

-- Hasta 3 (o más) fotos que la persona sube al crear la ruta, para el
-- collage de RouteCard — antes ese collage solo tomaba prestadas las fotos
-- de las paradas agregadas. Mismo criterio que `businesses.photos` /
-- `organizations.logo_url`: cada elemento puede ser una URL http(s) o la
-- ruta local de una imagen elegida con image_picker (este proyecto todavía
-- no usa object storage real). Sin migración, `select('*')` simplemente no
-- trae la columna y RouteModel.fromRow la lee como lista vacía — no hace
-- falta el manejo especial de "falta la migración" que sí necesita
-- `organizations` (ese es un embed por relación, este es una columna
-- plana).
alter table public.routes
  add column if not exists image_urls text[] not null default '{}';
