"""Prepare, inspect and import a sourced catalog into Nikara's linked Supabase.

No remote mutations without --apply. Credentials stay in memory. SQL inserts
the entire catalog in one transaction and never overwrites existing content.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid
from urllib.parse import urlparse

import requests
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
NAMESPACE = uuid.UUID('5a829620-f177-4785-8978-229d08823c66')
MAX_BYTES = 5 * 1024 * 1024
CATEGORIES = {'Hospedaje', 'Restaurante', 'Tour', 'Eco-destino', 'Cultura',
              'Transporte', 'Bienestar', 'Eventos', 'Compras y mercados',
              'Agroturismo / Fincas', 'Servicios para el viajero'}


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write_json(path, data):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def cli(*args):
    executable = 'npx.cmd' if os.name == 'nt' else 'npx'
    result = subprocess.run([executable, '--yes', 'supabase', *args], cwd=ROOT,
                            capture_output=True, text=True, encoding='utf-8')
    if result.returncode:
        # CLI output can contain credentials; never echo it into shared logs.
        raise ValueError('Falló Supabase CLI. Revisá la sesión y el proyecto enlazado.')
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise ValueError('Supabase CLI no devolvió JSON válido.') from error


def config():
    source = (ROOT / 'lib/core/supabase/supabase_config.dart').read_text(encoding='utf-8')
    url = os.environ.get('SUPABASE_URL') or re.search(r"const url = '([^']+)'", source).group(1)
    if not re.fullmatch(r'https://[a-z0-9]+\.supabase\.co', url):
        raise ValueError('SUPABASE_URL debe ser una URL de proyecto Supabase.')
    return url, urlparse(url).hostname.split('.')[0]


def load_catalog(path):
    catalog = read_json(path)
    ready = [b for b in catalog['businesses'] if b.get('ready') is True]
    seen = set()
    for b in ready:
        slug = b['slug']
        if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', slug) or slug in seen:
            raise ValueError(f'Slug duplicado o inválido: {slug}')
        seen.add(slug)
        for key in ['name', 'category', 'subcategory', 'description', 'city', 'address_text', 'location_source']:
            if not isinstance(b.get(key), str) or not b[key].strip():
                raise ValueError(f'{slug}: falta {key}')
        if b['category'] not in CATEGORIES:
            raise ValueError(f'{slug}: categoría fuera de los filtros de la app')
        if not (10.7 <= b['latitude'] <= 15.1 and -87.8 <= b['longitude'] <= -82.5):
            raise ValueError(f'{slug}: coordenadas fuera de Nicaragua')
        if len(b.get('images', [])) < 2 or len(b['images']) > 9:
            raise ValueError(f'{slug}: se requieren entre 2 y 9 fotos originales')
        for item in b['images']:
            if not item.get('source_page') or not item.get('alt') or item.get('reviewed') is not True:
                raise ValueError(f'{slug}: foto sin procedencia o revisión visual')
            if not item['url'].startswith('https://'):
                raise ValueError(f'{slug}: foto sin HTTPS')
    if not ready:
        raise ValueError('No hay negocios listos para importar.')
    return catalog, ready


def prepare(catalog_path, output):
    catalog, businesses = load_catalog(catalog_path)
    prepared = []
    for business in businesses:
        slug = business['slug']
        folder = output / 'images' / slug
        folder.mkdir(parents=True, exist_ok=True)
        assets = []
        source_hashes = set()
        for index, source in enumerate(business['images']):
            cached = ROOT / source.get('cache_path', '__missing__')
            if cached.is_file():
                original = cached.read_bytes()
            else:
                response = requests.get(source['url'], timeout=40, headers={'User-Agent': 'Nikara demo catalog/1.0'})
                response.raise_for_status()
                original = response.content
            digest = hashlib.sha256(original).hexdigest()
            if digest in source_hashes:
                raise ValueError(f'{slug}: foto original duplicada')
            source_hashes.add(digest)
            image = ImageOps.exif_transpose(Image.open(io.BytesIO(original))).convert('RGB')
            if min(image.size) < 500 or max(image.size) < 800:
                raise ValueError(f'{slug}: original demasiado pequeño ({image.size})')
            variants = [('gallery', image.copy())]
            if index == 0:
                # 4:3 matches the catalog cards. Never upscale a small original.
                width = int(min(1200, image.width, image.height * 4 / 3)) // 4 * 4
                variants.insert(0, ('cover', ImageOps.fit(image, (width, width * 3 // 4),
                                                        Image.Resampling.LANCZOS,
                                                        centering=tuple(source.get('focal_point', [0.5, 0.5])))))
            for kind, variant in variants:
                if kind == 'gallery':
                    variant.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
                path = folder / (f'{index:02}-{kind}.jpg')
                variant.save(path, 'JPEG', quality=86, optimize=True, progressive=True)
                data = path.read_bytes()
                if len(data) >= MAX_BYTES:
                    raise ValueError(f'{slug}: imagen excede el límite de Storage')
                with Image.open(path) as check:
                    check.verify()
                assets.append({'file': str(path.relative_to(ROOT)).replace('\\', '/'),
                               'kind': kind, 'width': variant.width, 'height': variant.height,
                               'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                               'source_url': source['url'], 'source_page': source['source_page'],
                               'alt': source['alt']})
        prepared.append({**{k: v for k, v in business.items() if k != 'images'},
                         'id': str(uuid.uuid5(NAMESPACE, slug)), 'assets': assets})
        print(f'Preparado: {business["name"]} ({len(assets)} imágenes)', flush=True)
    result = {'catalog_version': catalog['version'], 'researched_on': catalog['researched_on'],
              'catalog_sha256': hashlib.sha256(Path(catalog_path).read_bytes()).hexdigest(),
              'businesses': prepared}
    write_json(output / 'prepared.json', result)
    return result


def asset_bytes(asset):
    path = (ROOT / asset['file']).resolve()
    if ROOT not in path.parents:
        raise ValueError('Imagen fuera del workspace')
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != asset['sha256']:
        raise ValueError(f'La imagen cambió después de prepararla: {path.name}')
    with Image.open(io.BytesIO(data)) as image:
        if image.format != 'JPEG' or list(image.size) != [asset['width'], asset['height']]:
            raise ValueError('Formato o dimensiones no coinciden con el manifiesto')
        image.verify()
    if len(data) >= MAX_BYTES:
        raise ValueError('Imagen demasiado grande')
    return data


def object_path(owner, business, asset):
    return f'{owner}/curated-demo/{business["slug"]}/{asset["sha256"]}.jpg'


def rows_for(prepared, owner, url, publish):
    rows = []
    for b in prepared['businesses']:
        photos = []
        for asset in b['assets']:
            asset_bytes(asset)
            photos.append(url + '/storage/v1/object/public/businesses/' + object_path(owner, b, asset))
        rows.append({**{k: b.get(k, '') for k in ['name', 'category', 'subcategory', 'description',
                     'city', 'address_text', 'phone', 'instagram_handle', 'facebook_handle',
                     'schedules', 'access_details', 'other_notes']},
                     'id': b['id'], 'owner_id': owner,
                     'latitude': b['latitude'], 'longitude': b['longitude'],
                     'photos': photos, 'amenities': b.get('amenities', []),
                     'activities': b.get('activities', []),
                     'status': 'aprobado' if publish else 'pendiente'})
    return rows


def sql_literal(text):
    return "'" + text.replace("'", "''") + "'"


def make_sql(rows, owner):
    payload = sql_literal(json.dumps(rows, ensure_ascii=False))
    return f"""-- Generated by seed_tourism_businesses.py. Insert-only, atomic, repeatable.
begin;
set local standard_conforming_strings = on;
select pg_advisory_xact_lock(hashtext('nikara-curated-business-import'));
create temp table demo_seed_rows on commit drop as
select * from jsonb_to_recordset({payload}::jsonb) as x(
 id uuid,owner_id uuid,name text,category text,subcategory text,description text,
 city text,address_text text,latitude double precision,longitude double precision,
 phone text,instagram_handle text,facebook_handle text,schedules text,
 access_details text,other_notes text,photos text[],amenities text[],activities text[],status text
);
do $check$
begin
 if not exists(select 1 from public.profiles where id='{owner}'::uuid and role in ('emprendedor','admin')) then
  raise exception 'El dueño debe existir y tener rol emprendedor o admin';
 end if;
 if exists(select 1 from public.businesses b join demo_seed_rows s on b.id=s.id where b.owner_id is distinct from s.owner_id) then
  raise exception 'Un negocio del lote ya pertenece a otro usuario. No se transfiere automáticamente';
 end if;
 if exists(select 1 from public.businesses b join demo_seed_rows s
  on lower(trim(b.name))=lower(trim(s.name)) and lower(trim(b.city))=lower(trim(s.city)) where b.id<>s.id) then
  raise exception 'Ya existe un negocio con el mismo nombre y ciudad fuera del lote';
 end if;
end $check$;
insert into public.businesses (
 id,owner_id,name,category,subcategory,description,city,address_text,location,
 phone,instagram_handle,facebook_handle,schedules,access_details,other_notes,
 photos,amenities,activities,status,is_verified,show_host
)
select id,owner_id,name,category,subcategory,description,city,address_text,
 public.st_setsrid(public.st_makepoint(longitude,latitude),4326)::public.geography,
 phone,instagram_handle,facebook_handle,schedules,access_details,other_notes,
 photos,amenities,activities,status,false,false from demo_seed_rows
on conflict(id) do nothing;
commit;
select id,name,owner_id,status,cardinality(photos) as photo_count
from public.businesses where id in ({','.join(sql_literal(r['id'])+'::uuid' for r in rows)}) order by name;
"""


def credentials(ref):
    secret = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
    if secret:
        return secret
    keys = cli('projects', 'api-keys', '--project-ref', ref, '--reveal', '--output', 'json')
    for key in keys:
        if key.get('name') == 'service_role':
            return key['api_key']
    raise ValueError('No hay clave administrativa disponible para Storage.')


def apply(prepared, owner, url, ref, sql_path, output):
    key = credentials(ref)
    headers = {'apikey': key, 'Authorization': 'Bearer ' + key}
    # Fail before uploading if the account or catalog conflicts with live data.
    response = requests.get(url + '/rest/v1/profiles', headers=headers,
                            params={'id': 'eq.' + owner, 'select': 'id,role'}, timeout=30)
    response.raise_for_status()
    profiles = response.json()
    if len(profiles) != 1 or profiles[0]['role'] not in ['emprendedor', 'admin']:
        raise ValueError('La cuenta debe existir y ser emprendedor o admin.')
    response = requests.get(url + '/rest/v1/businesses', headers=headers,
                            params={'select': 'id,name,city,owner_id', 'limit': '10000'}, timeout=30)
    response.raise_for_status()
    existing = response.json()
    for b in prepared['businesses']:
        for old in existing:
            if old['id'] == b['id'] and old['owner_id'] != owner:
                raise ValueError(f'{b["name"]}: ya pertenece a otra cuenta')
            if old['id'] != b['id'] and (old['name'].strip().casefold(), old['city'].strip().casefold()) == (b['name'].strip().casefold(), b['city'].strip().casefold()):
                raise ValueError(f'{b["name"]}: ya existe fuera de este lote')
    uploaded = []
    for b in prepared['businesses']:
        for asset in b['assets']:
            data = asset_bytes(asset)
            path = object_path(owner, b, asset)
            public_url = url + '/storage/v1/object/public/businesses/' + path
            check = requests.get(public_url, timeout=30)
            if check.status_code in [400, 404]:
                response = requests.post(url + '/storage/v1/object/businesses/' + path,
                                         headers={**headers, 'Content-Type': 'image/jpeg',
                                                  'Cache-Control': 'max-age=31536000'}, data=data, timeout=40)
                response.raise_for_status()
                check = requests.get(public_url, timeout=30)
            check.raise_for_status()
            if hashlib.sha256(check.content).hexdigest() != asset['sha256']:
                raise ValueError('Storage devolvió bytes diferentes de la imagen verificada.')
            uploaded.append({'path': path, 'sha256': asset['sha256'], 'public_url': public_url})
        print(f'Fotos públicas verificadas: {b["name"]}', flush=True)
    # Keep a cleanup inventory if a later SQL failure leaves unreferenced objects.
    write_json(output / 'storage_inventory.json', uploaded)
    result = cli('db', 'query', '--linked', '--project-ref', ref, '--file', str(sql_path), '--output', 'json')
    records = result['rows']
    if len(records) != len(prepared['businesses']) or any(r['owner_id'] != owner for r in records):
        raise ValueError('La verificación posterior de registros no coincide con el lote.')
    write_json(output / 'import_result.json', {'owner_id': owner, 'records': records,
                                              'uploaded_images': len(uploaded)})
    print(f'Importación verificada: {len(records)} negocios, {len(uploaded)} imágenes. Repetir no duplica ni sobrescribe.')


def main():
    parser = argparse.ArgumentParser(description='Carga masiva de negocios reales para Nikara.')
    parser.add_argument('--catalog', type=Path, default=ROOT / 'supabase/demo/tourism_catalog.json')
    parser.add_argument('--output', type=Path, default=ROOT / 'supabase/demo/prepared')
    parser.add_argument('--prepare', action='store_true', help='Descargar y optimizar fotos; no modifica Supabase.')
    parser.add_argument('--owner-id', help='UUID del perfil que administrará todos los negocios del lote.')
    parser.add_argument('--publish', action='store_true', help='Publicar la carga administrativa con status aprobado.')
    parser.add_argument('--apply', action='store_true', help='Subir fotos e insertar el lote; requiere owner-id.')
    args = parser.parse_args()
    args.output = args.output.resolve()
    if ROOT not in args.output.parents:
        raise ValueError('La salida debe estar dentro del workspace.')
    load_catalog(args.catalog)
    if args.prepare:
        prepare(args.catalog, args.output)
    if not args.owner_id:
        if args.apply or args.publish:
            raise ValueError('Indicá --owner-id para aplicar o publicar.')
        print('Catálogo validado. Usá --owner-id para generar SQL o --prepare para preparar fotos.')
        return
    owner = str(uuid.UUID(args.owner_id))
    prepared = read_json(args.output / 'prepared.json')
    catalog, businesses = load_catalog(args.catalog)
    if (prepared.get('catalog_sha256') != hashlib.sha256(args.catalog.read_bytes()).hexdigest()
            or prepared['catalog_version'] != catalog['version']
            or [b['slug'] for b in businesses] != [b['slug'] for b in prepared['businesses']]):
        raise ValueError('El catálogo cambió. Volvé a ejecutar --prepare.')
    url, ref = config()
    rows = rows_for(prepared, owner, url, args.publish)
    sql_path = args.output / 'import.sql'
    sql_path.write_text(make_sql(rows, owner), encoding='utf-8')
    print(f'Plan: {len(rows)} negocios para {owner}; estado {rows[0]["status"]}. SQL: {sql_path}')
    if args.apply:
        apply(prepared, owner, url, ref, sql_path, args.output)
    else:
        print('Simulación: no se modificó Supabase. Agregá --apply para ejecutar.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, requests.RequestException, OSError, KeyError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
