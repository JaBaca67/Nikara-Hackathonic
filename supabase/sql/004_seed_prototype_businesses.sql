-- Nikara — reset + seed 3 prototype businesses for map testing.
--
-- Not applied automatically — same as 001/002/003, run this once by hand in
-- the Supabase dashboard: Project -> SQL Editor -> New query -> paste ->
-- Run. Safe to re-run (deletes and reinserts the same 3 rows every time).
--
-- Scoping note: the DELETE below only removes businesses owned by
-- dragonarc08@gmail.com's own auth.users id — not every row in the table.
-- "Elimina los registros de prueba antiguos" almost certainly means this
-- dev account's own earlier test businesses, not a blanket wipe of
-- `businesses` (which could destroy a real user's data if any other rows
-- exist). Widen the WHERE clause yourself if you do want a full wipe.
--
-- Optional-column note: `rating`, `is_active`, `tags` and `department`
-- aren't columns BusinessStorageService ever reads or writes (see its own
-- doc comment — this app's client only knows about id, owner_id, name,
-- category, description, city, address_text, location, phone,
-- instagram_handle, photos, is_verified). If your live `businesses` table
-- doesn't have them, MapScreen won't show them either way (category
-- already drives the chips/filter, and the map's "★ 4.8" pill only shows
-- once a real review exists — there's no reviews table yet). The script
-- below only touches those columns if they actually exist, so it runs
-- cleanly either way instead of guessing wrong and erroring out.

create extension if not exists pgcrypto; -- for gen_random_uuid()

do $$
declare
  v_owner_id uuid;
  v_isletas_id uuid := gen_random_uuid();
  v_laguna_id uuid := gen_random_uuid();
  v_mombacho_id uuid := gen_random_uuid();
begin
  select id into v_owner_id from auth.users where email = 'dragonark08@gmail.com';
  if v_owner_id is null then
    raise exception
      'No auth.users row for dragonark08@gmail.com — sign up/sign in with that account in the app first, then re-run this script.';
  end if;

  delete from public.businesses where owner_id = v_owner_id;

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

-- Verification — should return exactly these 3 rows.
select id, owner_id, name, category, city, address_text,
       ST_AsText(location) as location_wkt, photos
from public.businesses
order by created_at;
