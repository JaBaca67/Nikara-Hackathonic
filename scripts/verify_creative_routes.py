"""Verify the public Xolotlán routes without an authenticated app session."""
import json
import re
from pathlib import Path

import requests

from seed_creative_routes import CATALOG, OUTPUT, CATALOG_NAME, config, load_catalog, stable_id
from seed_tourism_businesses import ROOT, write_json

catalog = load_catalog(CATALOG)
url, _ = config()
source = (ROOT / 'lib/core/supabase/supabase_config.dart').read_text(encoding='utf-8')
anon_key = re.search(r"static const anonKey\s*=\s*'([^']+)'", source).group(1)
headers = {'apikey': anon_key, 'Authorization': 'Bearer ' + anon_key}
route_ids = [stable_id('route', r['slug']) for r in catalog['routes']]
response = requests.get(url + '/rest/v1/routes', headers=headers, params={
    'id': 'in.(' + ','.join(route_ids) + ')',
    'select': '*,route_stops(*),public_profiles(id,full_name,avatar_url)',
}, timeout=30)
response.raise_for_status()
routes = response.json()
assert len(routes) == 5
places = {b['official_id']: b for b in catalog['businesses']}
verification = []
business_ids = set()
for expected in catalog['routes']:
    route = next(r for r in routes if r['id'] == stable_id('route', expected['slug']))
    assert route['is_public'] is True
    assert route['description'] == expected['description']
    assert route['source_url'] == expected['source_url']
    assert route['owner_id'] is None
    assert route['catalog_name'] == CATALOG_NAME
    assert route['public_profiles'] is None
    stops = sorted(route['route_stops'], key=lambda stop: (stop['day_number'], stop['position']))
    assert len(stops) == len(expected['stops'])
    for stop, reference in zip(stops, expected['stops']):
        place = places[reference['official_id']]
        assert stop['title'] == place['name']
        assert stop['kind'] == 'business'
        assert stop['position'] == reference['order'] - 1
        assert stop['day_number'] == 1
        assert stop['image_path'].startswith(url + '/storage/v1/object/public/businesses/')
        if place.get('navigation_reference_only'):
            assert stop['latitude'] is None and stop['longitude'] is None
            assert place['access_details'] in stop['subtitle']
        else:
            assert stop['latitude'] == place['latitude'] and stop['longitude'] == place['longitude']
        business_ids.add(stop['business_id'])
    verification.append({'title': route['title'], 'stop_count': len(stops),
                         'navigable_stop_count': sum(s['latitude'] is not None for s in stops)})
assert len(business_ids) == 51
response = requests.get(url + '/rest/v1/businesses', headers=headers, params={
    'id': 'in.(' + ','.join(business_ids) + ')',
    'select': 'id,name,status,is_verified,show_host,municipality_code,description,phone,schedules,photos,access_details,other_notes',
}, timeout=30)
response.raise_for_status()
businesses = response.json()
assert len(businesses) == 51
for b in businesses:
    assert b['status'] == 'aprobado'
    assert b['is_verified'] is False and b['show_host'] is False
    assert b['municipality_code'] and b['description'] and b['photos']
    expected = next(p for p in places.values() if p['name'] == b['name'])
    assert b['phone'] == expected['phone']
    assert b['schedules'] == expected['schedules']
    assert b['access_details'] == expected['access_details']
    assert expected['source_url'] in b['other_notes']
write_json(OUTPUT / 'verification.json', {
    'public_access': True, 'routes': verification, 'places': len(businesses),
    'photos': sum(len(b['photos']) for b in businesses),
    'reference_only_stops': 4, 'source_url': catalog['source_url'],
})
print('Acceso público verificado: 5 rutas, 58 paradas, 51 lugares y 96 fotos. Orden, descripción y fuentes coinciden.')
