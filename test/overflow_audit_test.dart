import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/features/auth/presentation/screens/register_screen.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Deliberately worse than anything a real user is likely to type — long
/// enough to break any card/header that isn't actually protected by
/// `maxLines`/`Expanded`/`Flexible`, instead of only ever being exercised
/// against today's short seed data.
final _stressBusiness = BusinessModel(
  id: 'stress-test-id',
  name:
      'Complejo Ecoturístico y Balneario Familiar Laguna Escondida del '
      'Bosque Nuboso de Nicaragua',
  category: 'Eco Turismo y Aventura Extrema en la Montaña Nublada',
  description:
      'Una descripción extremadamente larga que simula lo que un dueño de '
      'negocio ansioso por vender su experiencia podría escribir sin '
      'pensar en los límites del diseño, con muchísimo texto seguido y '
      'sin saltos de línea naturales, para forzar el peor caso posible de '
      'renderizado de texto en tarjetas y encabezados de la aplicación.',
  city: 'Región Autónoma de la Costa Caribe Norte',
  locationText:
      'Del empalme de la carretera vieja hacia Bilwi, 4km al este, '
      'después del puente colgante, casa de dos plantas color turquesa',
  latitude: 12.1364,
  longitude: -86.2514,
  contactPhone: '+505 8888 8888',
  instagramLink: 'complejoecoturisticoybalneariofamiliarlagunaescondida',
  allowsReservations: true,
  price: 123456.99,
  amenities: const [
    'Wifi',
    'Estacionamiento',
    'Piscina',
    'Restaurante',
    'Guías locales',
    'Área de camping',
    'Mascotas permitidas',
    'Accesible',
    'Aire acondicionado',
    'Desayuno incluido',
  ],
  activities: const [
    'Senderismo',
    'Kayak',
    'Canopy',
    'Tour de Café',
    'Fotografía',
  ],
  hostName: 'Bartolomé de las Casas y Fuentes Rodríguez de la Vega Hernández',
  ownerId: 'stress-owner-id',
);

/// Two of the smallest real phone viewports still in circulation — if a
/// layout survives these without overflowing, it survives everything
/// larger too.
const _smallPhoneSizes = [
  Size(320, 568), // iPhone SE (1st gen)
  Size(360, 640), // common entry-level Android
];

void main() {
  setUpAll(() async {
    // Supabase.initialize() reaches for SharedPreferences internally
    // (GoTrue's local session storage), so the mock store has to exist
    // before initialize() runs, not just before each test.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Pumps [screen] at every size in [_smallPhoneSizes] and fails with a
  /// clear message (including which size broke) if Flutter's renderer
  /// throws anything — a `RenderFlex overflowed` error included, since
  /// that's a real `FlutterError` the test binding captures via
  /// [WidgetTester.takeException].
  Future<void> expectNoOverflow(
    WidgetTester tester,
    Widget screen,
    String label,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in _smallPhoneSizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: screen),
      );
      // Not pumpAndSettle: several screens have infinite/repeating
      // animations (shimmer skeletons, gradients) that would never settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason:
            '$label overflowed (or threw) at ${size.width}x${size.height}: '
            '$exception',
      );
    }
  }

  testWidgets('LoginScreen no desborda en pantallas pequeñas', (tester) async {
    await expectNoOverflow(tester, const LoginScreen(), 'LoginScreen');
  });

  testWidgets('RegisterScreen no desborda en pantallas pequeñas', (
    tester,
  ) async {
    await expectNoOverflow(tester, const RegisterScreen(), 'RegisterScreen');
  });

  testWidgets('BusinessDetailScreen con contenido extremo no desborda', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      BusinessDetailScreen(business: _stressBusiness),
      'BusinessDetailScreen',
    );
  });

  testWidgets('HomeScreen no desborda en pantallas pequeñas', (tester) async {
    await expectNoOverflow(tester, const HomeScreen(), 'HomeScreen');
  });

  testWidgets('MapScreen no desborda en pantallas pequeñas', (tester) async {
    await expectNoOverflow(tester, const MapScreen(), 'MapScreen');
  });

  testWidgets('ProfileScreen no desborda en pantallas pequeñas', (
    tester,
  ) async {
    await expectNoOverflow(tester, const ProfileScreen(), 'ProfileScreen');
  });

  testWidgets('SettingsScreen no desborda en pantallas pequeñas', (
    tester,
  ) async {
    await expectNoOverflow(tester, const SettingsScreen(), 'SettingsScreen');
  });

  testWidgets('RegisterBusinessWizard no desborda en pantallas pequeñas', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      const RegisterBusinessWizard(),
      'RegisterBusinessWizard',
    );
  });
}
