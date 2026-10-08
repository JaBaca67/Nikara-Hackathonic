import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import uuid
from seed_eco_activities import catalog, build_rows, make_sql, ROOT

class EcoSeedTests(unittest.TestCase):
    def setUp(self):
        self.data=catalog(ROOT/'docs/data/eco_activity_catalog.json')

    def test_coverage_and_sources(self):
        self.assertEqual(len({a['category'] for a in self.data['activities']}),10)
        for a in self.data['activities']:
            self.assertTrue(a['source']['url'].startswith('https://'))
            self.assertTrue(a['image_is_historical_reference'])
            self.assertIn('pendientes de confirmación',a['description'])

    def test_duplicate_and_unmarked_proposals_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'catalog.json'
            broken=copy.deepcopy(self.data)
            broken['activities'].append(broken['activities'][0])
            path.write_text(json.dumps(broken),encoding='utf8')
            with self.assertRaisesRegex(ValueError,'repetido'):catalog(path)
            broken=copy.deepcopy(self.data)
            broken['activities'][0]['description']='Actividad comunitaria real.'
            path.write_text(json.dumps(broken),encoding='utf8')
            with self.assertRaisesRegex(ValueError,'descripción conserva'):catalog(path)

    def test_repeat_preserves_identity_and_refuses_changed_assets(self):
        org='7a4feee5-cfa2-41ce-a683-fd090aac95ed'; owner='30a57d65-a20c-407e-bd7f-d07d8c3c54da'
        with tempfile.TemporaryDirectory() as temp:
            image=Path(temp)/'image.jpg'
            image.write_bytes(b'prepared-image-fixture')
            assets={'assets':[{'slug':a['slug'],'path':str(image),'sha256':hashlib.sha256(image.read_bytes()).hexdigest()} for a in self.data['activities']]}
            rows=build_rows(self.data,assets,org,owner,'https://example.supabase.co','2026-10-17')
            rerun=build_rows(self.data,assets,org,owner,'https://example.supabase.co','2026-11-17')
            image.write_bytes(b'changed-image-fixture')
            with self.assertRaisesRegex(ValueError,'Cambió una imagen'):
                build_rows(self.data,assets,org,owner,'https://example.supabase.co','2026-10-17')
        self.assertEqual([r['id'] for r in rows],[r['id'] for r in rerun])
        for row in rows:
            uuid.UUID(row['id'])
            self.assertEqual(row['organizer_id'],owner)
            self.assertEqual(row['organization_id'],org)
            self.assertFalse(row['organizer_verified'])
        sql=make_sql(rows,org,owner)
        self.assertIn('on conflict(id) do nothing',sql)
        self.assertIn('Conflicto de propietario',sql)
        self.assertNotIn('do update',sql)
        self.assertIn('begin;',sql)
        self.assertIn('commit;',sql)

if __name__=='__main__':unittest.main()
