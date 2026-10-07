import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';
import 'package:nikara_app/features/profile/presentation/widgets/passport_tab.dart';
import 'package:nikara_app/shared/services/main_tab_controller.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('el pasaporte abre la pestaña Mapa enfocada en Miraflor', (
    tester,
  ) async {
    addTearDown(() {
      MapFocusController().pendingFocus.value = null;
      MainTabController().requestedTab.value = null;
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: EdgeInsets.all(16), child: PassportTab()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leer postal'));
    await tester.tap(find.text('Leer postal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver en el mapa'));
    await tester.tap(find.text('Ver en el mapa'));
    final request = MapFocusController().pendingFocus.value;
    expect(request?.businessId, 'miraflor');
    expect(request?.latitude, 13.25);
    expect(request?.longitude, -86.25);
    expect(
      MainTabController().requestedTab.value,
      MapFocusController.mapTabIndex,
    );
    expect(find.text('Postal de ejemplo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('postal legible a 320dp, escala $scale, ambas caras y mapa', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var mapRequests = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TravelPostcardCard(
                    postcard: TravelPostcard.miraflorExample,
                    onMapRequested: () => mapRequests++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reserva Natural Miraflor'), findsOneWidget);
      await tester.tap(find.text('Leer postal'));
      await tester.pumpAndSettle();
      expect(find.text('Querido viajero:'), findsOneWidget);
      expect(find.text('Para: ti'), findsOneWidget);
      expect(find.text(TravelPostcard.miraflorExample.message), findsOneWidget);
      await tester.tap(find.text('Ver en el mapa'));
      await tester.pumpAndSettle();
      expect(mapRequests, 1);
      expect(find.text('Querido viajero:'), findsOneWidget);
      await tester.tap(find.text('Ver paisaje'));
      await tester.pumpAndSettle();
      expect(find.text('Reserva Natural Miraflor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el ajuste de reducir movimiento permite girar inmediatamente', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TravelPostcardCard(
                postcard: TravelPostcard.miraflorExample,
                onMapRequested: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leer postal'));
    await tester.pump();
    expect(find.text('Querido viajero:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
