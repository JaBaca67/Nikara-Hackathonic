import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/features/routes/data/route_travel_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/presentation/screens/route_travel_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  late RouteTravelService service;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = RouteTravelService.forTesting();
  });
  final route = RouteModel(
    id: 'travel-ui',
    ownerId: 'owner',
    title: 'Fin de semana en Granada',
    days: 2,
    createdAt: DateTime(2026),
    stops: const [
      RouteStopModel(
        kind: RouteStopKind.destination,
        sourceId: 'a',
        title: 'Museo',
      ),
      RouteStopModel(
        kind: RouteStopKind.destination,
        sourceId: 'b',
        title: 'Café',
        position: 1,
      ),
    ],
  );

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RouteTravelScreen(
          key: UniqueKey(),
          route: route,
          travelService: service,
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
  }

  testWidgets(
    'paradas sin ubicación mantienen checklist y bloquean solo navegar',
    (tester) async {
      await open(tester);
      final button = find.widgetWithText(FilledButton, 'Viajar a esta parada');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('Modo ruta'), findsOneWidget);
      expect(find.textContaining('2 paradas sin ubicación'), findsOneWidget);
      final visit = find.text('Marcar visita').first;
      await tester.scrollUntilVisible(
        find.text('1. Museo'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(visit);
      await tester.pump();
      await tester.tap(visit);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(service.active.value!.visitedCount, 1);
      expect(service.active.value!.nextForDay(1)!.title, 'Café');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('días vacíos se presentan como días libres y permiten volver', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Día 2'));
    await tester.pumpAndSettle();
    final freeDay = find.text('Día libre');
    await tester.ensureVisible(freeDay);
    expect(freeDay, findsOneWidget);
    expect(find.text('Viajar a esta parada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
