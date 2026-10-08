import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/eco/presentation/screens/eco_main_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_discovery_header.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/shared/widgets/category_icons_row.dart';
import 'package:nikara_app/shared/widgets/catalog_selection_field.dart';
import 'package:nikara_app/shared/widgets/geographic_filter_bar.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            for (final category in ['Limpieza', 'Fauna'])
              {
                'id': category,
                'title': '$category del río',
                'category': category,
                'description': 'Actividad ambiental',
                'location': category == 'Fauna' ? 'Managua' : 'Granada',
                'municipality_code': category == 'Fauna' ? '5525' : '7015',
                'start_time': DateTime.now()
                    .add(const Duration(days: 10))
                    .toIso8601String(),
                'created_at': DateTime(2026).toIso8601String(),
                'status': 'aprobado',
              },
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  });

  testWidgets(
    'ECO reutiliza cabecera y categorías y conecta búsqueda y filtro',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const EcoMainScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SearchHeaderWidget), findsOneWidget);
      expect(find.byType(CategoryIconsRow), findsOneWidget);
      expect(find.text('Actividades Ambientales'), findsOneWidget);
      expect(find.text('2 disponibles'), findsNothing);
      expect(find.byType(GeographicFilterBar), findsNothing);
      expect(find.text('Explorar destino'), findsNothing);
      expect(find.text('2 actividades para explorar'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Descubre más'),
        150,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(find.text('Descubre más'), findsOneWidget);
      expect(find.text('Limpieza del río'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'rio');
      await tester.pumpAndSettle();
      expect(find.text('Limpieza del río'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'Fauna');
      await tester.pumpAndSettle();
      expect(find.text('Fauna del río'), findsWidgets);
      expect(find.text('Limpieza del río'), findsNothing);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryIconsRow),
          matching: find.text('Limpieza'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fauna del río'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Limpieza del río'), findsWidgets);
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryIconsRow),
          matching: find.text('Todas'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Fauna del río'),
        150,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(find.text('Fauna del río'), findsWidgets);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('¿Dónde quieres explorar?'), findsOneWidget);
      await tester.tap(find.byType(CatalogSelectionField<String>));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en el catálogo'),
        'granada',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Granada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar destino'));
      await tester.pumpAndSettle();
      expect(find.text('Limpieza del río'), findsWidgets);
      expect(find.text('Fauna del río'), findsNothing);
      expect(find.text('Buscar en Granada...'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver todo Nicaragua'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Fauna del río'),
        150,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(find.text('Fauna del río'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final disconnect = Supabase.instance.client.realtime.disconnect(
        code: 1000,
      );
      await tester.pump(const Duration(seconds: 7));
      await disconnect;
    },
  );

  testWidgets(
    'el título ECO se lee completo en teléfono pequeño con texto grande',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: SearchHeaderWidget(
                headerContent: const EcoDiscoveryHeader(availableCount: 15),
                showNotifications: false,
                categoryContent: CategoryIconsRow(
                  categories: const ['Fauna', 'Limpieza'],
                  selected: null,
                  iconBuilder: (_) => Icons.eco_rounded,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('15 disponibles'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text('Actividades Ambientales')).height,
        greaterThan(50),
      );
    },
  );
}
