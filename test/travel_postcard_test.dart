import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';
import 'package:nikara_app/features/profile/presentation/widgets/passport_tab.dart';
import 'package:nikara_app/shared/services/main_tab_controller.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const business = BusinessModel(
    id: TravelPostcard.previewBusinessId,
    name: 'Restaurante El Zaguán',
    category: 'Restaurante',
    description:
        'Reconocido restaurante de gastronomía nicaragüense '
        'especializado en cortes de carne a la parrilla en un ambiente '
        'colonial acogedor.',
    city: 'Granada',
    locationText:
        'Del costado posterior de la Catedral 1/2 cuadra al Este, '
        'Granada, Nicaragua',
    latitude: 11.9293,
    longitude: -85.9525,
    contactPhone: '',
    hostName: '',
    schedules: 'Lunes a Domingo de 11:30 AM a 10:00 PM',
    localImagePaths: ['https://example.com/business-cover.jpg'],
  );

  test('la postal usa los datos actuales y la primera foto del negocio', () {
    final current = business.copyWith(
      name: 'Nombre actualizado',
      description: 'Descripción actualizada',
      localImagePaths: ['', 'https://example.com/new-cover.jpg'],
    );
    final postcard = TravelPostcard.fromBusiness(current);
    expect(postcard.id, current.id);
    expect(postcard.title, 'Nombre actualizado');
    expect(postcard.message, 'Descripción actualizada');
    expect(postcard.imagePath, 'https://example.com/new-cover.jpg');
    expect(postcard.artAsset, isNull);
    expect(postcard.region, current.city);
    expect(postcard.address, current.locationText);
    expect(postcard.schedules, current.schedules);
  });

  testWidgets('sin negocio disponible no aparecen postales ficticias', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: PassportTab()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TravelPostcardCard), findsNothing);
    expect(find.text('Tu primera postal te espera'), findsOneWidget);
    expect(find.text('Reserva Natural Miraflor'), findsNothing);
  });

  testWidgets('un destino sin un viaje sellado no pertenece al pasaporte', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PassportTab(postcards: [TravelPostcard.fromBusiness(business)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TravelPostcardCard), findsNothing);
    expect(find.text('Tu primera postal te espera'), findsOneWidget);
  });

  testWidgets('el pasaporte abre el pin real de El Zaguán en el mapa', (
    tester,
  ) async {
    addTearDown(() {
      MapFocusController().pendingFocus.value = null;
      MainTabController().requestedTab.value = null;
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: PassportTab(
                postcards: [
                  TravelPostcard.fromBusiness(
                    business,
                    sealedAt: DateTime.utc(2026, 10, 6, 18, 30),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PostcardThumbnail));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leer postal'));
    await tester.tap(find.text('Leer postal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver en el mapa'));
    await tester.tap(find.text('Ver en el mapa'));
    final request = MapFocusController().pendingFocus.value;
    expect(request?.businessId, business.id);
    expect(request?.latitude, business.latitude);
    expect(request?.longitude, business.longitude);
    expect(
      MainTabController().requestedTab.value,
      MapFocusController.mapTabIndex,
    );
    expect(find.textContaining('Sellada el'), findsOneWidget);
    final stamped = TravelPostcard.fromBusiness(
      business,
      sealedAt: DateTime.utc(2026, 10, 6, 18, 30),
    );
    expect(find.text(stamped.sealDateLabel), findsWidgets);
    expect(find.text(stamped.sealTimeLabel), findsWidgets);
    expect(
      find.text(
        'Sellada el ${stamped.sealDateLabel} a las ${stamped.sealTimeLabel}',
      ),
      findsOneWidget,
    );
    expect(find.text('N'), findsWidgets);
    expect(find.text(business.description), findsOneWidget);
    expect(find.text(business.locationText), findsOneWidget);
    expect(find.text(business.schedules), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('postal de negocio a 320dp, texto $scale y foto sin conexión', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
                    postcard: TravelPostcard.fromBusiness(
                      business,
                      sealedAt: DateTime.utc(2026, 10, 6, 18, 30),
                    ),
                    onMapRequested: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(business.name), findsOneWidget);
      await tester.tap(find.text('Leer postal'));
      await tester.pumpAndSettle();
      expect(find.text(business.locationText), findsOneWidget);
      expect(find.text(business.schedules), findsOneWidget);
      await tester.tap(find.text('Ver foto'));
      await tester.pumpAndSettle();
      expect(find.text(business.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'sin coordenadas ni foto no inventa una ubicación ni un paisaje',
    (tester) async {
      const noLocation = BusinessModel(
        id: 'no-location',
        name: 'Sin ubicación',
        category: 'Restaurante',
        description: '',
        city: '',
        locationText: '',
        contactPhone: '',
        hostName: '',
      );
      final postcard = TravelPostcard.fromBusiness(noLocation);
      expect(postcard.hasCoordinates, isFalse);
      expect(postcard.imagePath, isNull);
      expect(postcard.artAsset, isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PassportTab(
                postcards: [
                  TravelPostcard.fromBusiness(
                    noLocation,
                    sealedAt: DateTime.utc(2026, 10, 6, 18, 30),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PostcardThumbnail));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Leer postal'));
      await tester.tap(find.text('Leer postal'));
      await tester.pumpAndSettle();
      final mapButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(mapButton.onPressed, isNull);
      expect(find.text('Ubicación pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
