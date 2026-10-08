import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/shared/widgets/catalog_selection_field.dart';
import 'package:nikara_app/shared/widgets/geographic_filter_bar.dart';
import 'package:nikara_app/theme/app_theme.dart';

class _NoLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _NoLocation();
    await Supabase.initialize(
      url: 'https://home-filter.test.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/businesses')
                ? [
                    {
                      'id': 'managua',
                      'name': 'Lugar en Managua',
                      'city': 'Managua',
                      'category': 'Cultura',
                      'municipality_code': '5525',
                    },
                    {
                      'id': 'trinidad',
                      'name': 'Lugar en La Trinidad',
                      'city': 'La Trinidad',
                      'category': 'Cultura',
                      'municipality_code': '2525',
                    },
                  ]
                : [],
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  });
  testWidgets(
    'filtro junto a búsqueda abre destino y filtra también el destacado sin botón adicional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GeographicFilterBar), findsNothing);
      expect(find.text('Explorar destino'), findsNothing);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('¿Dónde quieres explorar?'), findsOneWidget);
      expect(find.text('Ordenar lugares'), findsOneWidget);
      await tester.tap(find.byType(CatalogSelectionField<String>));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en el catálogo'),
        'esteli',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Estelí'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar destino'));
      await tester.pumpAndSettle();
      expect(find.text('Lugar en La Trinidad'), findsWidgets);
      expect(find.text('Lugar en Managua'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      final disconnect = Supabase.instance.client.realtime.disconnect(
        code: 1000,
      );
      await tester.pump(const Duration(seconds: 7));
      await disconnect;
    },
  );
}
