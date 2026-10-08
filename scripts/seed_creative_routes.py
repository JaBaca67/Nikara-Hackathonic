"""Import the sourced Xolotlán circuit. Remote writes require --apply.

Existing places are reused by name/city; existing routes and their edited stops
are preserved. New places and routes are committed together in one transaction.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import uuid

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from PIL import Image, ImageOps, ImageDraw

from seed_tourism_businesses import ROOT, cli, config, credentials, sql_literal, write_json

NAMESPACE = uuid.UUID('6e51aaba-5cd3-4ff2-b9d4-6179324d4f72')
CATALOG = ROOT / 'scripts/data/xolotlan_catalog.json'
OUTPUT = ROOT / 'supabase/demo/xolotlan/prepared'
CATALOG_NAME = 'Circuito Creativo Xolotlán'


def stable_id(kind, key):
    return str(uuid.uuid5(NAMESPACE, kind + ':' + key))


def load_catalog(path):
    catalog = json.loads(path.read_text(encoding='utf-8'))
    ids = set()
    for b in catalog['businesses']:
        if b['official_id'] in ids:
            raise ValueError('Lugar oficial duplicado.')
        ids.add(b['official_id'])
        if not (10.7 <= b['latitude'] <= 15.1 and -87.8 <= b['longitude'] <= -82.5):
            raise ValueError('Coordenada fuera de Nicaragua.')
        if not b['description'] or not b['source_url'].startswith('https://ciudadcreativa.managua.gob.ni/'):
            raise ValueError('Falta descripción o procedencia oficial.')
        if any(not image.startswith('https://') for image in b['images']):
            raise ValueError('Las imágenes deben usar HTTPS.')
    slugs = set()
    for r in catalog['routes']:
        if r['slug'] in slugs or not r['stops']:
            raise ValueError('Ruta duplicada o vacía.')
        slugs.add(r['slug'])
        if not 1 <= r['days'] <= 30 or not 0 < len(r['description']) <= 500 or len(r['title']) > 60:
            raise ValueError('Duración, título o descripción inválida.')
        if [s['order'] for s in r['stops']] != list(range(1, len(r['stops']) + 1)):
            raise ValueError('El orden oficial debe ser continuo.')
        if any(s['official_id'] not in ids for s in r['stops']):
            raise ValueError('Parada sin ficha de lugar.')
        if len({s['official_id'] for s in r['stops']}) != len(r['stops']):
            raise ValueError('Una parada se repite en la misma ruta.')
    return catalog


def prepare(catalog, output):
    image_dir = output / 'images'
    image_dir.mkdir(parents=True, exist_ok=True)

    def download(b):
        session = requests.Session()
        session.mount('https://', HTTPAdapter(max_retries=Retry(
            total=3, backoff_factor=0.5, status_forcelist=[429, 500, 502, 503, 504])))
        assets = []
        for index, url in enumerate(b['images']):
            path = image_dir / f'{b["slug"]}-{index + 1}.jpg'
            if not path.exists():
                response = session.get(url, timeout=(15, 45))
                response.raise_for_status()
                with Image.open(io.BytesIO(response.content)) as original:
                    img = ImageOps.exif_transpose(original).convert('RGB')
                    img.thumbnail((1600, 1600))
                    img.save(path, 'JPEG', quality=85, optimize=True)
            data = path.read_bytes()
            with Image.open(path) as img:
                img.verify()
            assets.append({'path': str(path.relative_to(ROOT)), 'source_url': url,
                           'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
        return {**b, 'id': stable_id('place', b['official_id']), 'assets': assets}

    with ThreadPoolExecutor(max_workers=6) as pool:
        businesses = list(pool.map(download, catalog['businesses']))
    prepared = {**catalog, 'businesses': businesses}
    write_json(output / 'prepared.json', prepared)
    # Contact sheets make mismatched source photographs reviewable before upload.
    for batch in range(0, len(businesses), 18):
        group = businesses[batch:batch + 18]
        sheet = Image.new('RGB', (900, 220 * ((len(group) + 2) // 3)), 'white')
        draw = ImageDraw.Draw(sheet)
        for index, b in enumerate(group):
            if not b['assets']:
                continue
            with Image.open(ROOT / b['assets'][0]['path']) as img:
                thumb = ImageOps.fit(img, (294, 180))
            x, y = (index % 3) * 300, (index // 3) * 220
            sheet.paste(thumb, (x, y))
            draw.text((x + 3, y + 184), b['official_id'] + ' ' + b['name'][:32], fill='black')
        sheet.save(output / f'covers-{batch // 18 + 1}.jpg')
    print(f'Preparados {len(businesses)} lugares y {sum(len(b["assets"]) for b in businesses)} fotos.', flush=True)
    return prepared


def rows_for(catalog, owner, url):
    businesses = []
    for b in catalog['businesses']:
        photos = []
        for asset in b['assets']:
            data = (ROOT / asset['path']).read_bytes()
            if hashlib.sha256(data).hexdigest() != asset['sha256']:
                raise ValueError('La imagen local cambió después de preparar.')
            photos.append(url + '/storage/v1/object/public/businesses/' +
                          f'{owner}/creative-circuits/{b["slug"]}/{asset["sha256"]}.jpg')
        businesses.append({**{k: b[k] for k in ['name', 'category', 'subcategory', 'description', 'city',
                            'address_text', 'latitude', 'longitude', 'phone', 'schedules',
                            'access_details', 'other_notes']}, 'id': b['id'], 'official_id': b['official_id'],
                           'photos': photos})
    by_id = {b['official_id']: b for b in businesses}
    source_by_id = {b['official_id']: b for b in catalog['businesses']}
    routes, stops = [], []
    for route in catalog['routes']:
        rid = stable_id('route', route['slug'])
        routes.append({'id': rid, 'catalog_name': CATALOG_NAME,
                       **{k: route[k] for k in ['title', 'description', 'days', 'source_url']}})
        for stop in route['stops']:
            place = by_id[stop['official_id']]
            source = source_by_id[stop['official_id']]
            note = place['access_details']
            stops.append({'id': stable_id('stop', route['slug'] + ':' + stop['official_id']),
                          'route_id': rid, 'official_id': stop['official_id'], 'day_number': 1,
                          'position': stop['order'] - 1, 'title': place['name'],
                          'subtitle': 'Managua' + (' · ' + note if note else ''),
                          'category': 'gastronomico' if place['category'] == 'Restaurante' else 'turistico',
                          'business_category': place['category'],
                          'image_path': place['photos'][0] if place['photos'] else None,
                          # A lagoon centroid is not a visitor entrance. Preserve it in the
                          # place/source manifest, but do not navigate travelers into water.
                          'latitude': None if source.get('navigation_reference_only') else place['latitude'],
                          'longitude': None if source.get('navigation_reference_only') else place['longitude']})
    return businesses, routes, stops


def make_sql(businesses, routes, stops, owner):
    owner = str(uuid.UUID(owner))
    business_json, route_json, stop_json = [sql_literal(json.dumps(rows, ensure_ascii=False))
                                          for rows in [businesses, routes, stops]]
    return f"""-- Generated by seed_creative_routes.py. Atomic and insert-only.
begin;
set local standard_conforming_strings = on;
select pg_advisory_xact_lock(hashtext('nikara-creative-circuit-import'));
create temp table creative_places on commit drop as
select * from jsonb_to_recordset({business_json}::jsonb) as x(
 id uuid,official_id text,name text,category text,subcategory text,description text,city text,
 address_text text,latitude double precision,longitude double precision,phone text,schedules text,
 access_details text,other_notes text,photos text[]);
create temp table creative_routes on commit drop as
select * from jsonb_to_recordset({route_json}::jsonb) as x(
 id uuid,title text,description text,days integer,source_url text,catalog_name text);
create temp table creative_stops on commit drop as
select * from jsonb_to_recordset({stop_json}::jsonb) as x(
 id uuid,route_id uuid,official_id text,day_number integer,position integer,title text,subtitle text,
 category text,business_category text,image_path text,latitude double precision,longitude double precision);
create temp table creative_place_matches on commit drop as
select s.official_id,b.id,b.status from creative_places s join public.businesses b on b.id=s.id or
 (translate(lower(btrim(b.name)),'áéíóúüñ','aeiouun')=translate(lower(btrim(s.name)),'áéíóúüñ','aeiouun')
  and lower(btrim(b.city))=lower(btrim(s.city)));
do $guard$
begin
 if not exists(select 1 from public.profiles where id='{owner}'::uuid and role in ('emprendedor','admin')) then
  raise exception 'El administrador del lote debe existir y ser emprendedor o admin';
 end if;
 if exists(select 1 from creative_place_matches group by official_id having count(*)>1) then
  raise exception 'Hay más de una ficha para un lugar; resolver duplicados antes de importar';
 end if;
 if exists(select 1 from creative_place_matches where status is distinct from 'aprobado') then
  raise exception 'Un lugar existente no está publicado; revisar sin modificarlo automáticamente';
 end if;
 if exists(select 1 from public.routes r join creative_routes s using(id)
           where r.owner_id is not null or r.catalog_name is distinct from s.catalog_name) then
  raise exception 'Una ruta del lote no pertenece al catálogo global; revisar la migración 048';
 end if;
end $guard$;
insert into public.businesses(id,owner_id,name,category,subcategory,description,city,address_text,location,
 phone,schedules,access_details,other_notes,photos,status,is_verified,show_host)
select s.id,'{owner}'::uuid,s.name,s.category,s.subcategory,s.description,s.city,s.address_text,
 public.st_setsrid(public.st_makepoint(s.longitude,s.latitude),4326)::public.geography,
 s.phone,s.schedules,s.access_details,s.other_notes,s.photos,'aprobado',false,false
from creative_places s where not exists(select 1 from creative_place_matches m where m.official_id=s.official_id);
create temp table creative_place_ids on commit drop as
select s.official_id,coalesce(m.id,s.id) as business_id from creative_places s
left join creative_place_matches m using(official_id);
create temp table creative_new_routes on commit drop as
with inserted as (
 insert into public.routes(id,owner_id,title,description,days,is_public,status,source_url,image_urls,catalog_name)
 select s.id,null,s.title,s.description,s.days,true,'active',s.source_url,'{{}}'::text[],s.catalog_name
 from creative_routes s on conflict(id) do nothing returning id
) select id from inserted;
insert into public.route_stops(id,route_id,day_number,position,kind,business_id,title,subtitle,
 category,image_path,latitude,longitude)
select s.id,s.route_id,s.day_number,s.position,'business',m.business_id,s.title,s.subtitle,
 s.category,
 coalesce(b.photos[1],s.image_path),s.latitude,s.longitude
from creative_stops s join creative_new_routes n on n.id=s.route_id
join creative_place_ids m using(official_id) join public.businesses b on b.id=m.business_id;
commit;
select r.id,r.title,r.description,r.owner_id,r.is_public,r.source_url,r.catalog_name,
 count(s.id)::integer as stop_count,count(s.latitude)::integer as navigable_stop_count
from public.routes r left join public.route_stops s on s.route_id=r.id
where r.id in ({','.join(sql_literal(r['id'])+'::uuid' for r in routes)})
group by r.id order by r.title;
"""


def apply(catalog, owner, url, ref, sql_path, output):
    key = credentials(ref)
    headers = {'apikey': key, 'Authorization': 'Bearer ' + key}
    # Check ownership and duplicates before uploading any objects.
    response = requests.get(url + '/rest/v1/profiles', headers=headers,
                            params={'id': 'eq.' + owner, 'select': 'id,role'}, timeout=30)
    response.raise_for_status()
    if len(response.json()) != 1 or response.json()[0]['role'] not in ['admin', 'emprendedor']:
        raise ValueError('La cuenta administradora no existe o no tiene el rol requerido.')
    response = requests.get(url + '/rest/v1/businesses', headers=headers,
                            params={'select': 'id,name,city,status', 'limit': 10000}, timeout=30)
    response.raise_for_status()
    existing = response.json()
    def normalized(text):
        return text.strip().lower().translate(str.maketrans('áéíóúüñ', 'aeiouun'))
    reused = set()
    for place in catalog['businesses']:
        matches = [b for b in existing if b['id'] == place['id'] or
                   (normalized(b['name']), normalized(b['city'])) ==
                   (normalized(place['name']), normalized(place['city']))]
        if len(matches) > 1 or any(b['status'] != 'aprobado' for b in matches):
            raise ValueError('Un lugar existente requiere revisión antes de la carga.')
        if matches:
            reused.add(place['official_id'])
    route_ids = ','.join(stable_id('route', r['slug']) for r in catalog['routes'])
    response = requests.get(url + '/rest/v1/routes', headers=headers,
                            params={'id': f'in.({route_ids})', 'select': 'id,owner_id,catalog_name'}, timeout=30)
    response.raise_for_status()
    if any(r['owner_id'] is not None or r['catalog_name'] != CATALOG_NAME for r in response.json()):
        raise ValueError('Una ruta existente no pertenece al catálogo global; revisar la migración 048.')
    assets = [(b, a) for b in catalog['businesses'] if b['official_id'] not in reused for a in b['assets']]

    def upload(pair):
        b, asset = pair
        data = (ROOT / asset['path']).read_bytes()
        path = f'{owner}/creative-circuits/{b["slug"]}/{asset["sha256"]}.jpg'
        public_url = url + '/storage/v1/object/public/businesses/' + path
        response = requests.get(public_url, timeout=30)
        if response.status_code in [400, 404]:
            response = requests.post(url + '/storage/v1/object/businesses/' + path,
                                     headers={**headers, 'Content-Type': 'image/jpeg'}, data=data, timeout=45)
            response.raise_for_status()
            response = requests.get(public_url, timeout=30)
        response.raise_for_status()
        if hashlib.sha256(response.content).hexdigest() != asset['sha256']:
            raise ValueError('La foto pública no coincide con la preparada.')
        return {'path': path, 'sha256': asset['sha256'], 'public_url': public_url}

    inventory = []
    with ThreadPoolExecutor(max_workers=6) as pool:
        for uploaded in pool.map(upload, assets):
            inventory.append(uploaded)
            write_json(output / 'storage_inventory.json', inventory)
            if len(inventory) % 12 == 0:
                print(f'Fotos públicas verificadas: {len(inventory)}/{len(assets)}', flush=True)
    result = cli('db', 'query', '--linked', '--project-ref', ref, '--file', str(sql_path), '--output', 'json')
    write_json(output / 'import_result.json', result)
    records = result['rows']
    if len(records) != len(catalog['routes']) or any(
            r['owner_id'] is not None or r['catalog_name'] != CATALOG_NAME for r in records):
        raise ValueError('El resultado de rutas no coincide con el lote esperado.')
    print(f'Carga verificada: {len(records)} rutas, {len(reused)} lugares reutilizados, {len(inventory)} fotos nuevas verificadas.', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', type=Path, default=CATALOG)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--owner-id')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    catalog = load_catalog(args.catalog)
    print(f'Catálogo validado: {len(catalog["routes"])} rutas y {len(catalog["businesses"])} lugares.', flush=True)
    if args.apply and not args.owner_id:
        raise ValueError('--apply requiere --owner-id.')
    if args.prepare:
        catalog = prepare(catalog, args.output)
    elif args.owner_id:
        prepared = json.loads((args.output / 'prepared.json').read_text(encoding='utf-8'))
        prepared_businesses = [{k: v for k, v in b.items() if k not in ['id', 'assets']}
                               for b in prepared['businesses']]
        if prepared['routes'] != catalog['routes'] or prepared_businesses != catalog['businesses']:
            raise ValueError('El catálogo preparado cambió; volver a ejecutar --prepare.')
        catalog = prepared
    if args.owner_id:
        owner = str(uuid.UUID(args.owner_id))
        url, ref = config()
        businesses, routes, stops = rows_for(catalog, owner, url)
        sql_path = args.output / 'import.sql'
        sql_path.write_text(make_sql(businesses, routes, stops, owner), encoding='utf-8')
        if args.apply:
            apply(catalog, owner, url, ref, sql_path, args.output)
        else:
            print('SQL preparado sin modificar Supabase: ' + str(sql_path))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, requests.RequestException) as error:
        raise SystemExit(f'No se completó la carga: {error}')
