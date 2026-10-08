"""Import boundaries: malformed catalogs and modified images must not reach DB."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image
import seed_tourism_businesses as seed


class SeedValidationTest(unittest.TestCase):
    def setUp(self):
        (seed.ROOT / 'build').mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=seed.ROOT / 'build')
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.catalog = {
            'version': 'test', 'researched_on': '2026-10-07',
            'businesses': [{
                'slug': 'test-business', 'ready': True, 'name': 'Prueba',
                'category': 'Hospedaje', 'subcategory': 'Hotel', 'description': 'Prueba',
                'city': 'Jinotega', 'address_text': 'Prueba', 'latitude': 13.1,
                'longitude': -86.0, 'location_source': 'https://example.com/map',
                'images': [{'url': f'https://example.com/{i}.jpg',
                            'source_page': 'https://example.com/', 'alt': 'Foto',
                            'reviewed': True} for i in range(2)],
            }],
        }

    def catalog_file(self):
        path = self.folder / 'catalog.json'
        path.write_text(json.dumps(self.catalog), encoding='utf-8')
        return path

    def test_pending_candidates_are_excluded(self):
        self.catalog['businesses'].append({'slug': 'pending', 'ready': False})
        _, businesses = seed.load_catalog(self.catalog_file())
        self.assertEqual([b['slug'] for b in businesses], ['test-business'])

    def test_duplicate_slugs_are_rejected(self):
        self.catalog['businesses'].append(dict(self.catalog['businesses'][0]))
        with self.assertRaisesRegex(ValueError, 'Slug duplicado'):
            seed.load_catalog(self.catalog_file())

    def test_unreviewed_photo_is_rejected(self):
        self.catalog['businesses'][0]['images'][0]['reviewed'] = False
        with self.assertRaisesRegex(ValueError, 'revisión visual'):
            seed.load_catalog(self.catalog_file())

    def test_coordinates_outside_nicaragua_are_rejected(self):
        self.catalog['businesses'][0]['latitude'] = 40
        with self.assertRaisesRegex(ValueError, 'fuera de Nicaragua'):
            seed.load_catalog(self.catalog_file())

    def test_modified_photo_is_rejected_before_upload(self):
        path = self.folder / 'photo.jpg'
        Image.new('RGB', (800, 600), 'green').save(path, 'JPEG')
        data = path.read_bytes()
        asset = {'file': str(path.relative_to(seed.ROOT)), 'width': 800,
                 'height': 600, 'sha256': hashlib.sha256(data).hexdigest()}
        self.assertEqual(seed.asset_bytes(asset), data)
        path.write_bytes(data + b'changed')
        with self.assertRaisesRegex(ValueError, 'cambió después'):
            seed.asset_bytes(asset)

    def test_prepare_preserves_orientation_and_never_upscales(self):
        path = self.folder / 'portrait.jpg'
        image = Image.new('RGB', (900, 1200), 'green')
        exif = Image.Exif()
        exif[274] = 6
        image.save(path, 'JPEG', exif=exif)
        second = self.folder / 'landscape.jpg'
        Image.new('RGB', (1000, 700), 'blue').save(second, 'JPEG')
        for source, cache in zip(self.catalog['businesses'][0]['images'], [path, second]):
            source['cache_path'] = str(cache.relative_to(seed.ROOT))
        prepared = seed.prepare(self.catalog_file(), self.folder / 'output')
        assets = prepared['businesses'][0]['assets']
        self.assertEqual((assets[0]['width'], assets[0]['height']), (1200, 900))
        self.assertEqual((assets[1]['width'], assets[1]['height']), (1200, 900))
        self.assertEqual((assets[2]['width'], assets[2]['height']), (1000, 700))
        for asset in assets:
            with Image.open(seed.ROOT / asset['file']) as check:
                self.assertEqual(check.format, 'JPEG')
                self.assertEqual(len(check.getexif()), 0)


if __name__ == '__main__':
    unittest.main()
