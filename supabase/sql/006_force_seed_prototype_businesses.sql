-- Nikara — force-insert the 3 prototype businesses, guaranteed to commit.
--
-- Not applied automatically — same as 001-005, run by hand in the Supabase
-- dashboard: Project -> SQL Editor -> New query -> paste -> Run.
--
-- Why 004 silently did nothing: it looked up owner_id via
-- `select ... where email = 'dragonarc08@gmail.com'` (or 'dragonark08@...'
-- depending which spelling actually ran) and `raise exception`'d if that
-- email had no auth.users row — which rolls back the entire DO block,
-- including the DELETE+INSERT before it. 005's diagnosis confirmed RLS
-- wasn't the issue (relrowsecurity = false), so that rollback is what
-- happened.
--
-- This version can't hit that dead end: it still tries
-- 'dragonarc08@gmail.com' first, but if that doesn't match, it falls back
-- to whichever auth.users row exists (oldest first) instead of raising —
-- `businesses.owner_id` is a NOT NULL FK into a real user, so *some*
-- existing id is required, but it no longer has to be that exact one. It
-- only raises if auth.users has literally zero rows (impossible once
-- you've ever logged into the app once).
--
-- Idempotent: deletes any existing rows with these 3 exact names first, so
-- re-running this after a fix doesn't create duplicates.

create extension if not exists pgcrypto; -- for gen_random_uuid()

do $$
declare
  v_owner_id uuid;
  v_isletas_id uuid := gen_random_uuid();
  v_laguna_id uuid := gen_random_uuid();
  v_mombacho_id uuid := gen_random_uuid();
begin
  select id into v_owner_id from auth.users where email = 'dragonarc08@gmail.com';

  if v_owner_id is null then
    select id into v_owner_id from auth.users order by created_at limit 1;
  end if;

  if v_owner_id is null then
    raise exception
      'auth.users está completamente vacía — crea/inicia sesión con una cuenta en la app al menos una vez antes de correr este script.';
  end if;

  delete from public.businesses
  where name in ('Isletas de Granada', 'Laguna de Apoyo Resort', 'Finca Eco-Senderos Mombacho');

  insert into public.businesses (
    id, owner_id, name, category, description, city, address_text,
    location, phone, instagram_handle, photos
  )
  values
    (v_isletas_id, v_owner_id, 'Isletas de Granada', 'Tours',
     'Tour en lancha por las Isletas de Granada.', 'Granada', 'Granada, Nicaragua',
     ST_SetSRID(ST_MakePoint(-85.9180, 11.9130), 4326)::geography,
     '', '', ARRAY['https://images.unsplash.com/photo-1544644181-1484b3fdfc62']),
    (v_laguna_id, v_owner_id, 'Laguna de Apoyo Resort', 'Lagunas',
     'Kayak y descanso frente a la Laguna de Apoyo.', 'Masaya', 'Masaya, Nicaragua',
     ST_SetSRID(ST_MakePoint(-86.0333, 11.9333), 4326)::geography,
     '', '', ARRAY['https://images.unsplash.com/photo-1507525428034-b723cf961d3e']),
    (v_mombacho_id, v_owner_id, 'Finca Eco-Senderos Mombacho', 'Eco',
     'Senderismo eco-turístico en las faldas del volcán Mombacho.', 'Granada', 'Granada, Nicaragua',
     ST_SetSRID(ST_MakePoint(-85.9833, 11.8333), 4326)::geography,
     '', '', ARRAY['https://images.unsplash.com/photo-1448375240586-882707db888b']);

  -- Optional columns — only touched if they actually exist on your live
  -- table (BusinessStorageService never reads/writes these; see 004's
  -- note). Harmless no-op if they're not there.
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'businesses' and column_name = 'rating'
  ) then
    execute 'update public.businesses set rating = $1 where id = $2' using 4.8, v_isletas_id;
    execute 'update public.businesses set rating = $1 where id = $2' using 4.9, v_laguna_id;
    execute 'update public.businesses set rating = $1 where id = $2' using 4.7, v_mombacho_id;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'businesses' and column_name = 'is_active'
  ) then
    execute 'update public.businesses set is_active = true where id in ($1, $2, $3)'
      using v_isletas_id, v_laguna_id, v_mombacho_id;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'businesses' and column_name = 'tags'
  ) then
    execute 'update public.businesses set tags = $1 where id = $2'
      using ARRAY['Tour en lancha', 'Tours'], v_isletas_id;
    execute 'update public.businesses set tags = $1 where id = $2'
      using ARRAY['Kayak', 'Lagunas'], v_laguna_id;
    execute 'update public.businesses set tags = $1 where id = $2'
      using ARRAY['Senderismo', 'Eco'], v_mombacho_id;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'businesses' and column_name = 'department'
  ) then
    execute 'update public.businesses set department = $1 where id = $2' using 'Granada', v_isletas_id;
    execute 'update public.businesses set department = $1 where id = $2' using 'Masaya', v_laguna_id;
    execute 'update public.businesses set department = $1 where id = $2' using 'Granada', v_mombacho_id;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'businesses' and column_name = 'image_url'
  ) then
    execute 'update public.businesses set image_url = $1 where id = $2'
      using 'https://images.unsplash.com/photo-1544644181-1484b3fdfc62', v_isletas_id;
    execute 'update public.businesses set image_url = $1 where id = $2'
      using 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e', v_laguna_id;
    execute 'update public.businesses set image_url = $1 where id = $2'
      using 'https://images.unsplash.com/photo-1448375240586-882707db888b', v_mombacho_id;
  end if;
end $$;

-- Visual confirmation — should show exactly the 3 rows above.
select * from public.businesses;
