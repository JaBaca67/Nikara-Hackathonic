"""Catálogo ECO investigado: preparación, SQL revisable y carga masiva repetible.

Por defecto no modifica Supabase. --prepare descarga portadas; --apply carga
Storage y ejecuta una transacción. Reutiliza una organización y su propietario.
"""
from __future__ import annotations
import argparse
from datetime import date, datetime, time, timedelta, timezone
import hashlib
import io
import json
from pathlib import Path
import re
import uuid
from urllib.parse import urlsplit

import truststore
truststore.inject_into_ssl()  # certificados del sistema, sin desactivar TLS
import requests
from PIL import Image, ImageOps, UnidentifiedImageError
from seed_tourism_businesses import ROOT, cli, config, credentials, sql_literal

NAMESPACE = uuid.UUID('cc8f9a55-ffb2-45df-bb67-c7fb2b7ebc76')
BUCKET = 'eco_activities'

def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))

def write(path, value):
    Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def catalog(path):
    data=read(path)
    source=(ROOT/'lib/features/eco/domain/models/eco_activity_model.dart').read_text(encoding='utf8')
    categories=set(re.findall(r"'([^']+)'",source.split('kEcoCategories = [',1)[1].split('];',1)[0]))
    entries=data['activities']
    if {a['category'] for a in entries} != categories:
        raise ValueError('El lote debe cubrir todas las categorías ECO de la app.')
    seen=set()
    for a in entries:
        if not re.fullmatch(r'[a-z0-9-]+',a['slug']) or a['slug'] in seen:
            raise ValueError('Slug inválido o repetido.')
        seen.add(a['slug'])
        if a['title'].startswith('Demo · ') or not a['description'].startswith('Actividad de demostración'):
            raise ValueError('Los títulos van sin prefijo; la descripción conserva la nota de demostración.')
        if not a['source']['url'].startswith('https://') or not a['image_url'].startswith('https://'):
            raise ValueError('La fuente y la portada deben tener URL HTTPS.')
        if not 1 <= a['max_capacity'] <= 100 or not re.fullmatch(r'\d{4}',a['municipality_code']):
            raise ValueError('Cupo o municipio inválido.')
    return data

def prepare(data, output):
    (output/'images').mkdir(parents=True,exist_ok=True)
    assets=[]
    for a in data['activities']:
        parsed=urlsplit(a['image_url'])
        response=requests.get(a['image_url'],headers={'User-Agent':'Mozilla/5.0',
            'Referer':parsed.scheme+'://'+parsed.netloc+'/'},timeout=45)
        response.raise_for_status()
        if len(response.content)>20*1024*1024:
            raise ValueError('La imagen fuente supera 20 MB.')
        with Image.open(io.BytesIO(response.content)) as original:
            photo=ImageOps.exif_transpose(original).convert('RGB')
            original_size=photo.size
            width=min(1600,photo.width,photo.height*3//2)//3*3
            if width<600:
                raise ValueError(f'{a["slug"]}: portada demasiado pequeña: {original_size}')
            photo=ImageOps.fit(photo,(width,width*2//3),method=Image.Resampling.LANCZOS)
            path=output/'images'/f'{a["slug"]}.jpg'
            photo.save(path,'JPEG',quality=88,optimize=True,progressive=True)
        raw=path.read_bytes()
        if len(raw)>5*1024*1024: raise ValueError('Portada supera límite de Storage.')
        assets.append({'slug':a['slug'],'path':str(path.resolve()),'sha256':hashlib.sha256(raw).hexdigest(),
                       'source_url':a['image_url'],'original_size':original_size,
                       'size':[width,width*2//3],'bytes':len(raw)})
        print(f'Preparada {a["slug"]}: {width}x{width*2//3}, {len(raw)} bytes',flush=True)
    write(output/'assets.json',{'assets':assets})

def build_rows(data,assets,organization,owner,url,base_date):
    base=date.fromisoformat(base_date)
    result=[]
    by_slug={a['slug']:a for a in assets['assets']}
    for a in data['activities']:
        asset=by_slug[a['slug']]
        raw=Path(asset['path']).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=asset['sha256']:
            raise ValueError('Cambió una imagen desde la preparación; vuelve a prepararla.')
        activity_id=str(uuid.uuid5(NAMESPACE,f'{organization}/{a["slug"]}'))
        object_path=f'{owner}/demo/{activity_id}/{asset["sha256"][:20]}.jpg'
        dt=datetime.combine(base+timedelta(days=a['day_offset']),time(8),timezone(timedelta(hours=-6)))
        result.append({'id':activity_id,'title':a['title'],'category':a['category'],
            'description':a['description']+'\n\nReferencia: '+a['source']['publisher']+' ('+a['source']['published']+'). '+a['source']['url']+'\nFoto de archivo: '+a['image_credit']+'. No documenta una jornada de Níkara.',
            'location':a['location'],'municipality_code':a['municipality_code'],'start_time':dt.isoformat(),
            'max_capacity':a['max_capacity'],'organizer_id':owner,'organization_id':organization,
            'organizer_name':'Níkara','organizer_verified':False,'requirements':a['requirements'],
            'image_url':url+'/storage/v1/object/public/'+BUCKET+'/'+object_path,
            'status':'aprobado','asset_path':asset['path'],'asset_sha256':asset['sha256'], 'object_path':object_path})
    return result

def make_sql(rows,organization,owner):
    db_rows=[{k:v for k,v in r.items() if k not in ('asset_path','asset_sha256','object_path')} for r in rows]
    payload=sql_literal(json.dumps(db_rows,ensure_ascii=False))
    return f"""begin;
do $$ begin
 perform pg_advisory_xact_lock(hashtext('nikara-eco-demo'));
 if not exists(select 1 from organizations where id='{organization}' and owner_id='{owner}' and status='aprobado') then
   raise exception 'La organización aprobada no pertenece a la cuenta indicada.';
 end if;
end $$;
create temporary table eco_seed_input on commit drop as
 select * from jsonb_populate_recordset(null::public.eco_activities,{payload}::jsonb);
do $$ begin
 if exists(select 1 from eco_seed_input n join eco_activities a using(id)
   where a.organizer_id is distinct from n.organizer_id or a.organization_id is distinct from n.organization_id) then
   raise exception 'Conflicto de propietario; no se reasignará una actividad.';
 end if;
 if exists(select 1 from eco_seed_input n join eco_activities a on a.title=n.title and a.municipality_code=n.municipality_code and a.id<>n.id) then
   raise exception 'Existe una propuesta igual fuera de este lote.';
 end if;
end $$;
insert into eco_activities(id,title,description,category,location,municipality_code,start_time,max_capacity,organizer_id,organization_id,organizer_name,organizer_verified,requirements,image_url,status)
 select id,title,description,category,location,municipality_code,start_time,max_capacity,organizer_id,organization_id,organizer_name,organizer_verified,requirements,image_url,status
 from eco_seed_input on conflict(id) do nothing;
commit;
select id,title,category,municipality_code,organization_id,status,image_url from eco_activities
 where id in ({','.join(sql_literal(r['id'])+'::uuid' for r in rows)}) order by category;
"""

def apply(rows,sql_path,output,url,ref,organization,owner):
    key=credentials(ref)
    headers={'apikey':key,'Authorization':'Bearer '+key}
    r=requests.get(url+'/rest/v1/organizations',headers=headers,params={'id':'eq.'+organization,'select':'id,owner_id,status'},timeout=30)
    r.raise_for_status()
    if r.json()!=[{'id':organization,'owner_id':owner,'status':'aprobado'}]:
        raise ValueError('Verifica la organización y su propietario antes de cargar imágenes.')
    r=requests.get(url+'/rest/v1/eco_activities',headers=headers,params={'select':'id,title,municipality_code,organizer_id,organization_id','limit':10000},timeout=30)
    r.raise_for_status()
    for new in rows:
        for old in r.json():
            if old['id']==new['id'] and (old['organizer_id']!=owner or old['organization_id']!=organization):
                raise ValueError('Conflicto de propietario.')
            if old['id']!=new['id'] and (old['title'],old['municipality_code'])==(new['title'],new['municipality_code']):
                raise ValueError('Propuesta repetida fuera del lote.')
    inventory=[]
    for row in rows:
        photo=Path(row['asset_path']).read_bytes()
        public=requests.get(row['image_url'],timeout=30)
        if public.status_code in (400,404):
            upload=requests.post(url+'/storage/v1/object/'+BUCKET+'/'+row['object_path'],headers={**headers,'Content-Type':'image/jpeg','Cache-Control':'max-age=31536000'},data=photo,timeout=45)
            upload.raise_for_status()
            public=requests.get(row['image_url'],timeout=30)
        public.raise_for_status()
        if hashlib.sha256(public.content).hexdigest()!=row['asset_sha256']:
            raise ValueError('Storage devolvió una imagen diferente.')
        inventory.append({'activity_id':row['id'],'object_path':row['object_path'],'sha256':row['asset_sha256']})
        write(output/'storage_inventory.json',inventory)
        print('Portada pública verificada: '+row['category'],flush=True)
    result=cli('db','query','--linked','--project-ref',ref,'--file',str(sql_path),'--output','json')
    write(output/'import_result.json',result)
    print(f'Carga completada: {len(rows)} actividades bajo Níkara. Repetir conserva los registros existentes.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog',type=Path,default=ROOT/'docs/data/eco_activity_catalog.json')
    parser.add_argument('--output',type=Path,default=ROOT/'supabase/demo/eco')
    parser.add_argument('--prepare',action='store_true')
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--organization-id')
    parser.add_argument('--owner-id')
    parser.add_argument('--base-date',help='YYYY-MM-DD, solo afecta registros nuevos')
    args=parser.parse_args()
    data=catalog(args.catalog)
    args.output.mkdir(parents=True,exist_ok=True)
    if args.prepare:prepare(data,args.output)
    if not args.organization_id or not args.owner_id:
        if args.apply:parser.error('--apply requiere --organization-id y --owner-id')
        print('Catálogo válido. Para generar SQL indica --organization-id y --owner-id.')
        return
    organization=str(uuid.UUID(args.organization_id)); owner=str(uuid.UUID(args.owner_id))
    url,ref=config()
    rows=build_rows(data,read(args.output/'assets.json'),organization,owner,url,args.base_date or data['base_date'])
    sql_path=args.output/'import.sql'
    sql_path.write_text(make_sql(rows,organization,owner),encoding='utf8')
    write(args.output/'planned_rows.json',rows)
    print(f'Plan preparado: {len(rows)} actividades. SQL: {sql_path}')
    if args.apply:apply(rows,sql_path,args.output,url,ref,organization,owner)
    else:print('No se modificó Supabase; añade --apply para ejecutar el plan.')

if __name__=='__main__':
    try: main()
    except (ValueError,requests.RequestException,UnidentifiedImageError) as error:
        raise SystemExit('No se completó la carga: '+str(error))
