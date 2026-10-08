import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nikara_app/core/models/geographic_destination.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/home/domain/nearby_businesses.dart';
import 'package:nikara_app/shared/widgets/geographic_filter_bar.dart';
import 'package:nikara_app/shared/widgets/catalog_selection_field.dart';
import 'package:nikara_app/theme/app_theme.dart';

Position position({double accuracy = 20, DateTime? timestamp}) => Position(
  latitude: 12,
  longitude: -86,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

BusinessModel business(
  String id,
  double? latitude, {
  double? longitude = -86,
}) => BusinessModel(
  id: id,
  name: id,
  category: 'Cultura',
  description: '',
  city: 'Managua',
  locationText: '',
  contactPhone: '',
  hostName: '',
  latitude: latitude,
  longitude: longitude,
);

class _LocationPlatform extends GeolocatorPlatform {
  int reads = 0;
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position result = position();
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    return result;
  }
}

void main() {
  test('Estelí departamento incluye La Trinidad; municipio no', () {
    const department = GeographicDestination(department: 'Estelí');
    const municipality = GeographicDestination(
      department: 'Estelí',
      municipalityCode: '2515',
    );
    final trinidad = resolveMunicipality('La Trinidad');
    expect(department.matches(trinidad), isTrue);
    expect(municipality.matches(trinidad), isFalse);
    expect(municipality.matches(resolveMunicipality('esteli')), isTrue);
    expect(department.matches(resolveMunicipality('Managua')), isFalse);
    expect(department.matches(null), isFalse);
    expect(const GeographicDestination().matches(null), isTrue);
  });
  test('compatibilidad solo reconoce nombres completos y unívocos', () {
    expect(resolveMunicipality('manguas'), isNull);
    expect(resolveMunicipality('Wiwilí'), isNull);
    expect(resolveMunicipality('Wiwilí', department: 'Jinotega'), isNotNull);
    expect(resolveMunicipality('bilwi')?.municipality, 'Puerto Cabezas');
    expect(
      resolveLegacyEcoMunicipality('Parque central, La Trinidad')?.department,
      'Estelí',
    );
    expect(resolveLegacyEcoMunicipality('Camino a Estelí'), isNull);
    expect(resolveLegacyEcoMunicipality('Managua, Estelí'), isNull);
  });
  test('cercanía excluye coordenadas inválidas y ordena sin radio', () {
    final data = [
      business('lejos', 14),
      business('medio', 12.1),
      business('cerca', 12.01),
      business('sin-pin', null),
      business('invalido', 100),
      business('nan', double.nan),
    ];
    expect(nearbyBusinesses(data, position()).map((b) => b.id), [
      'cerca',
      'medio',
      'lejos',
    ]);
    expect(nearbyBusinesses([data[3], data[4], data[5]], position()), isEmpty);
  });
  test('cercanía muestra como máximo los seis lugares más próximos', () {
    final data = [
      for (var i = 8; i >= 1; i--) business('lugar-$i', 12 + i / 100),
    ];
    expect(nearbyBusinesses(data, position()).map((b) => b.id), [
      for (var i = 1; i <= 6; i++) 'lugar-$i',
    ]);
  });
  test(
    'ubicación cacheada se renueva y se descarta al perder permiso o precisión',
    () async {
      final previous = GeolocatorPlatform.instance;
      final platform = _LocationPlatform();
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = previous);
      final service = LocationService();
      await service.getCurrentPosition(forceRefresh: true);
      await service.getCurrentPosition();
      expect(platform.reads, 1);
      await service.getCurrentPosition(forceRefresh: true);
      expect(platform.reads, 2);
      platform.permission = LocationPermission.deniedForever;
      expect(await service.getCurrentPosition(), isNull);
      platform.permission = LocationPermission.whileInUse;
      platform.result = position(accuracy: 5000);
      expect(await service.getCurrentPosition(forceRefresh: true), isNull);
      platform.result = position(
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(await service.getCurrentPosition(forceRefresh: true), isNull);
      platform.enabled = false;
      expect(await service.getCurrentPosition(), isNull);
    },
  );
  testWidgets('selector permite departamento, municipio y quitar destino', (
    tester,
  ) async {
    GeographicDestination value = const GeographicDestination();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: GeographicFilterBar(
              destination: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Explorar destino'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CatalogSelectionField<String>));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'esteli');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Estelí'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar destino'));
    await tester.pumpAndSettle();
    expect(value.department, 'Estelí');
    expect(value.municipalityCode, isNull);
    await tester.tap(find.text('Destino: Estelí'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CatalogSelectionField<NicaraguaOriginPlace>));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'trinidad');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'La Trinidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar destino'));
    await tester.pumpAndSettle();
    expect(
      municipalityByCode(value.municipalityCode)?.municipality,
      'La Trinidad',
    );
    await tester.tap(find.byTooltip('Quitar filtro de destino'));
    await tester.pumpAndSettle();
    expect(value.isActive, isFalse);
  });
}
