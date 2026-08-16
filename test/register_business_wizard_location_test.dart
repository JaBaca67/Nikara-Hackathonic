import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Regression coverage for "editar un negocio pide ubicación aunque ya
/// tenga coordenadas guardadas" — `RegisterBusinessWizard.initState` only
/// pre-fills `_confirmedLocation` (what gates step 2's "Siguiente" and the
/// final save) when `existingBusiness.latitude`/`longitude` are non-null.
/// Before `BusinessStorageService._parseLocation` learned to decode hex
/// WKB, a business whose `location` came back from Supabase in that shape
/// would load with null coordinates and hit exactly this false "ubicación
/// requerida" block despite having a real saved pin — see
/// business_location_parsing_test.dart for that fix's own coverage. This
/// file instead locks in the wizard-side symptom directly.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final businessWithLocation = BusinessModel(
    id: 'biz-with-location',
    name: 'Isletas de Granada',
    category: 'Tour',
    description: 'Tour en lancha por las Isletas de Granada.',
    city: 'Granada',
    locationText: 'Granada, Nicaragua',
    latitude: 12.1363,
    longitude: -86.2513,
    contactPhone: '+505 8888 8888',
    allowsReservations: false,
    hostName: 'Anfitrión de prueba',
    ownerId: 'owner-1',
  );

  testWidgets(
    'precarga las coordenadas existentes y no exige confirmar ubicación de nuevo',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RegisterBusinessWizard(
            existingBusiness: businessWithLocation,
            initialStep: 1, // Step 2 (4b): Ubicación y pin en el mapa.
          ),
        ),
      );
      // Not pumpAndSettle: the map picker's GoogleMap can keep the pump
      // queue busy indefinitely in the test environment.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The confirmed-location hint only renders when `_confirmedLocation`
      // is already set — proof the wizard read the business' real lat/lng
      // on initState instead of starting from a blank pin.
      expect(find.textContaining('Coordenadas guardadas'), findsOneWidget);
      expect(find.textContaining('12.1363'), findsOneWidget);
      expect(find.textContaining('-86.2513'), findsOneWidget);

      // The blocking prompt is only ever shown via a SnackBar from
      // _nextFromStep2's `_confirmedLocation == null` guard — since the
      // location arrived pre-filled, nothing should have triggered it.
      expect(find.textContaining('Ubica tu negocio en el mapa'), findsNothing);
    },
  );
}
