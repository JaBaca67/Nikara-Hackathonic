-- Ajusta solo las 10 actividades de demostración de Níkara registradas aquí.
-- Conserva el propietario, las descripciones y el resto de sus datos.
begin;
do $$
declare mismatches integer;
begin
  with proposed(id, old_title, new_title) as (values
    ('21a1b9d8-ed3f-596b-b5f3-379583fc2882'::uuid, 'Demo · Reforestación del bosque de Tomabú', 'Reforestar el bosque de pino de Tomabú'),
    ('71df4dc8-e79b-5cf8-8036-02949bb8a3cd'::uuid, 'Demo · Guardianes de tortugas en Quelantaro', 'Tortugas marinas de Quelantaro'),
    ('835b26ed-7120-5720-8a17-030989a60524'::uuid, 'Demo · Playa limpia en El Tránsito', 'Jornada costera en El Tránsito'),
    ('9806c56d-0505-5d98-9127-f61dd0edd70f'::uuid, 'Demo · Madera recuperada y artesanía en Limay', 'Artesanía circular en San Juan de Limay'),
    ('56252eaa-c699-598f-b4c8-37f979e04b03'::uuid, 'Demo · Explorar y cuidar la cuenca del río Dipilto', 'Caminata por la cuenca del río Dipilto'),
    ('37f9df3c-a294-5eb5-8d4f-cc1818520dc2'::uuid, 'Demo · Suelos vivos en la Serranía de Amerrisque', 'Suelos vivos en la Serranía de Amerrisque'),
    ('6d268738-68cc-50ae-a9b8-282a86f2b349'::uuid, 'Demo · Semillas y viveros de las brumas', 'Viveros forestales de Jinotega'),
    ('d08e6fdf-60ce-52ef-bc9a-f6975f0ac65a'::uuid, 'Demo · Aprender a separar residuos en Muy Muy', 'Clasificación de residuos en Muy Muy'),
    ('70b3b9f4-a366-5abd-8259-abff7f25451f'::uuid, 'Demo · Observar biodiversidad en Peñas Blancas', 'Observación de biodiversidad en Peñas Blancas'),
    ('24304cdc-7d4e-5072-b204-37aee18f09af'::uuid, 'Demo · Agua limpia y saneamiento en La Trinidad', 'Saneamiento ambiental en La Trinidad')
  )
  select count(*) into mismatches
  from proposed n left join public.eco_activities a on a.id=n.id
  where a.id is null
    or a.organization_id is distinct from '7a4feee5-cfa2-41ce-a683-fd090aac95ed'::uuid
    or a.title not in (n.old_title,n.new_title);
  if mismatches <> 0 then
    raise exception 'Se encontraron títulos ausentes o editados; no se aplicaron cambios.';
  end if;
  with proposed(id, old_title, new_title) as (values
    ('21a1b9d8-ed3f-596b-b5f3-379583fc2882'::uuid, 'Demo · Reforestación del bosque de Tomabú', 'Reforestar el bosque de pino de Tomabú'),
    ('71df4dc8-e79b-5cf8-8036-02949bb8a3cd'::uuid, 'Demo · Guardianes de tortugas en Quelantaro', 'Tortugas marinas de Quelantaro'),
    ('835b26ed-7120-5720-8a17-030989a60524'::uuid, 'Demo · Playa limpia en El Tránsito', 'Jornada costera en El Tránsito'),
    ('9806c56d-0505-5d98-9127-f61dd0edd70f'::uuid, 'Demo · Madera recuperada y artesanía en Limay', 'Artesanía circular en San Juan de Limay'),
    ('56252eaa-c699-598f-b4c8-37f979e04b03'::uuid, 'Demo · Explorar y cuidar la cuenca del río Dipilto', 'Caminata por la cuenca del río Dipilto'),
    ('37f9df3c-a294-5eb5-8d4f-cc1818520dc2'::uuid, 'Demo · Suelos vivos en la Serranía de Amerrisque', 'Suelos vivos en la Serranía de Amerrisque'),
    ('6d268738-68cc-50ae-a9b8-282a86f2b349'::uuid, 'Demo · Semillas y viveros de las brumas', 'Viveros forestales de Jinotega'),
    ('d08e6fdf-60ce-52ef-bc9a-f6975f0ac65a'::uuid, 'Demo · Aprender a separar residuos en Muy Muy', 'Clasificación de residuos en Muy Muy'),
    ('70b3b9f4-a366-5abd-8259-abff7f25451f'::uuid, 'Demo · Observar biodiversidad en Peñas Blancas', 'Observación de biodiversidad en Peñas Blancas'),
    ('24304cdc-7d4e-5072-b204-37aee18f09af'::uuid, 'Demo · Agua limpia y saneamiento en La Trinidad', 'Saneamiento ambiental en La Trinidad')
  )
  update public.eco_activities a set title=n.new_title
  from proposed n where a.id=n.id and a.title=n.old_title
    and a.organization_id='7a4feee5-cfa2-41ce-a683-fd090aac95ed'::uuid;
end $$;
commit;
