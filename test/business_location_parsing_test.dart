import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';

/// [BusinessStorageService.businessFromRow] never touches
/// `Supabase.instance.client`, so these tests exercise it directly against
/// hand-built rows — no Supabase/SharedPreferences bootstrap needed.
///
/// This covers the actual bug behind "un negocio se guarda pero no aparece
/// en el mapa": Postgres' default text output for a `geography`/`geometry`
/// column (what a plain `select location` returns, no `ST_AsText`/
/// `ST_AsGeoJSON` wrapper) is hex-encoded (E)WKB, not WKT — a shape the
/// parser didn't previously understand, so it silently returned null
/// coordinates and the pin never made it onto a loaded [BusinessModel].
void main() {
  final storage = BusinessStorageService();

  Map<String, dynamic> rowWithLocation(dynamic location) => {
    'id': 'biz-1',
    'owner_id': 'owner-1',
    'name': 'Negocio de prueba',
    'category': 'Tours',
    'description': '',
    'city': 'Granada',
    'address_text': '',
    'location': location,
    'phone': '',
    'instagram_handle': '',
    'photos': <dynamic>[],
  };

  /// Hand-encodes an (E)WKB `POINT(lng lat)` exactly the way PostGIS'
  /// `geography_out` does, then hex-encodes it — the same bytes Postgres
  /// puts on the wire, reproduced independently of the parser under test.
  String encodeEwkbHex({
    required double lng,
    required double lat,
    bool bigEndian = false,
    bool includeSrid = true,
    int srid = 4326,
  }) {
    final endian = bigEndian ? Endian.big : Endian.little;
    const wkbSridFlag = 0x20000000;
    final typeAndFlags = 1 | (includeSrid ? wkbSridFlag : 0);

    final length = 1 + 4 + (includeSrid ? 4 : 0) + 16;
    final bytes = ByteData(length);
    var offset = 0;
    bytes.setUint8(offset, bigEndian ? 0 : 1);
    offset += 1;
    bytes.setUint32(offset, typeAndFlags, endian);
    offset += 4;
    if (includeSrid) {
      bytes.setUint32(offset, srid, endian);
      offset += 4;
    }
    bytes.setFloat64(offset, lng, endian);
    offset += 8;
    bytes.setFloat64(offset, lat, endian);

    final buffer = bytes.buffer.asUint8List();
    return buffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  group('hex WKB (PostGIS default geography_out shape)', () {
    test('little-endian con SRID (el formato real de Supabase)', () {
      final hex = encodeEwkbHex(lng: -86.2513, lat: 12.1363);
      final business = storage.businessFromRow(rowWithLocation(hex));
      expect(business.longitude, closeTo(-86.2513, 1e-9));
      expect(business.latitude, closeTo(12.1363, 1e-9));
    });

    test('big-endian con SRID', () {
      final hex = encodeEwkbHex(lng: -85.918, lat: 11.913, bigEndian: true);
      final business = storage.businessFromRow(rowWithLocation(hex));
      expect(business.longitude, closeTo(-85.918, 1e-9));
      expect(business.latitude, closeTo(11.913, 1e-9));
    });

    test('WKB plano sin SRID', () {
      final hex = encodeEwkbHex(
        lng: -86.0333,
        lat: 11.9333,
        includeSrid: false,
      );
      final business = storage.businessFromRow(rowWithLocation(hex));
      expect(business.longitude, closeTo(-86.0333, 1e-9));
      expect(business.latitude, closeTo(11.9333, 1e-9));
    });

    test('coordenadas negativas y positivas se distinguen del signo', () {
      final hex = encodeEwkbHex(lng: 3.5, lat: -7.25);
      final business = storage.businessFromRow(rowWithLocation(hex));
      expect(business.longitude, closeTo(3.5, 1e-9));
      expect(business.latitude, closeTo(-7.25, 1e-9));
    });

    test('mayúsculas/minúsculas en el hex no importan', () {
      final hex = encodeEwkbHex(lng: -86.2513, lat: 12.1363).toUpperCase();
      final business = storage.businessFromRow(rowWithLocation(hex));
      expect(business.longitude, closeTo(-86.2513, 1e-9));
    });
  });

  group('formatos ya soportados (no deben romperse)', () {
    test('EWKT con prefijo SRID', () {
      final business = storage.businessFromRow(
        rowWithLocation('SRID=4326;POINT(-86.2513 12.1363)'),
      );
      expect(business.longitude, closeTo(-86.2513, 1e-9));
      expect(business.latitude, closeTo(12.1363, 1e-9));
    });

    test('WKT plano', () {
      final business = storage.businessFromRow(
        rowWithLocation('POINT(-86.2513 12.1363)'),
      );
      expect(business.longitude, closeTo(-86.2513, 1e-9));
      expect(business.latitude, closeTo(12.1363, 1e-9));
    });

    test('GeoJSON', () {
      final business = storage.businessFromRow(
        rowWithLocation({
          'type': 'Point',
          'coordinates': [-86.2513, 12.1363],
        }),
      );
      expect(business.longitude, closeTo(-86.2513, 1e-9));
      expect(business.latitude, closeTo(12.1363, 1e-9));
    });
  });

  group('entradas inválidas nunca fabrican coordenadas', () {
    test('location null', () {
      final business = storage.businessFromRow(rowWithLocation(null));
      expect(business.latitude, isNull);
      expect(business.longitude, isNull);
    });

    test('string que no es hex ni WKT', () {
      final business = storage.businessFromRow(
        rowWithLocation('no es una ubicación'),
      );
      expect(business.latitude, isNull);
      expect(business.longitude, isNull);
    });

    test('hex de longitud impar', () {
      final business = storage.businessFromRow(rowWithLocation('abc'));
      expect(business.latitude, isNull);
      expect(business.longitude, isNull);
    });

    test('hex demasiado corto para ser un punto', () {
      final business = storage.businessFromRow(rowWithLocation('0101'));
      expect(business.latitude, isNull);
      expect(business.longitude, isNull);
    });
  });
}
