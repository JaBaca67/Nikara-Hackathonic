import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/features/auth/presentation/screens/register_screen.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_eco_activity_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_organization_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_activity_card.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/public_user_profile_screen.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/presentation/screens/create_route_wizard_screen.dart';
import 'package:nikara_app/features/routes/presentation/screens/full_screen_map_screen.dart';
import 'package:nikara_app/features/routes/presentation/screens/route_detail_screen.dart';
import 'package:nikara_app/features/routes/presentation/screens/routes_main_screen.dart';
import 'package:nikara_app/features/routes/presentation/widgets/route_card.dart';
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

/// Mismo criterio que [_stressBusiness], pero para el módulo ECO: título,
/// lugar, organizador y requisitos mucho más largos que cualquier actividad
/// real, para reventar la tarjeta extendida y el detalle si algún texto
/// quedó sin `maxLines`/`Expanded`.
final _stressActivity = EcoActivityModel(
  id: 'stress-eco-id',
  title:
      'Jornada Comunitaria de Reforestación, Limpieza de Senderos y '
      'Educación Ambiental en las Laderas del Cerro Apante',
  description:
      'Una descripción larguísima de la actividad, escrita por una '
      'organización entusiasta que quiere contar cada detalle de la '
      'jornada sin pensar en los límites del diseño, con muchísimo texto '
      'seguido y sin saltos de línea naturales, para forzar el peor caso '
      'posible de renderizado en la tarjeta y en el detalle.',
  category: 'Reforestación y Restauración de Ecosistemas Degradados',
  location:
      'Reserva Natural Cerro Apante, del empalme de la carretera vieja '
      '4km al este, entrada del sendero principal, Matagalpa',
  latitude: 12.9,
  longitude: -85.9,
  startTime: DateTime(2030, 5, 24, 9),
  maxCapacity: 40,
  organizerName: 'Bartolomé de las Casas y Fuentes Rodríguez de la Vega',
  organizerId: 'stress-organizer-id',
  organizerVerified: true,
  // Publicada en nombre de una fundación: ejercita el bloque "Organizador"
  // (logo + nombre + VERIFICADO) con un nombre y un handle imposibles.
  organizationId: 'stress-org-id',
  organizationName:
      'Fundación Nicaragua Verde para la Conservación de los Bosques Nubosos',
  organizationHandle: 'fundacionnicaraguaverdeconservacionbosques',
  organizationVerified: true,
  requirements: const [
    'Ropa cómoda, botas cerradas y gorra para el sol de la mañana',
    'Botella de agua reutilizable de al menos un litro y protector solar',
    'Guantes de jardinería (opcional, la organización presta algunos)',
  ],
  createdAt: DateTime(2030, 1, 1),
  // Inscritos con nombre y foto: ejercita la pila de avatares reales de la
  // tarjeta y las filas enlazables de la pestaña "Participantes".
  participants: [
    EcoParticipant(
      userId: 'stress-participant-1',
      joinedAt: DateTime(2030, 1, 2),
      fullName: 'María Auxiliadora de los Ángeles Sandoval Bermúdez',
      avatarUrl:
          'https://example.supabase.co/storage/v1/object/public/'
          'avatars/stress/1.jpg',
    ),
    EcoParticipant(
      userId: 'stress-participant-2',
      joinedAt: DateTime(2030, 1, 3),
      fullName: 'Juan',
    ),
  ],
  participantCount: 18,
);

/// La fundación dueña de [_stressActivity], con la misma lógica de datos
/// deliberadamente peores que los reales.
final _stressOrganization = OrganizationModel(
  id: 'stress-org-id',
  name: 'Fundación Nicaragua Verde para la Conservación de los Bosques Nubosos',
  handle: 'fundacionnicaraguaverdeconservacionbosques',
  description:
      'Una misión larguísima, escrita por una organización que quiere '
      'contar cada detalle de su trabajo de conservación sin pensar en los '
      'límites del diseño, con muchísimo texto seguido y sin saltos de '
      'línea naturales.',
  ownerId: 'stress-owner-id',
  createdAt: DateTime(2026, 1, 1),
);

/// Un itinerario con títulos de parada mucho más largos que cualquiera
/// real, para exigir el timeline del detalle, el collage de la tarjeta y
/// los chips de categoría.
final _stressRoute = RouteModel(
  id: 'stress-route-id',
  ownerId: 'stress-owner-id',
  title:
      'Fin de semana larguísimo entre Granada, Masaya y la Isla de Ometepe '
      'con paradas gastronómicas y jornadas ambientales',
  days: 2,
  isPublic: true,
  createdAt: DateTime(2026, 1, 1),
  // Sin creatorName a propósito: exige el fallback "Alguien de Níkara" de
  // la cabecera de Comunidad en vez de solo el caso feliz.
  stops: [
    const RouteStopModel(
      kind: RouteStopKind.destination,
      sourceId: 'laguna-de-apoyo',
      title: 'Reserva Natural Laguna de Apoyo y su mirador de Catarina',
      subtitle: 'Masaya · Nicaragua · 18 km',
      dayNumber: 1,
    ),
    const RouteStopModel(
      kind: RouteStopKind.ecoActivity,
      sourceId: 'stress-eco-id',
      title:
          'Jornada Comunitaria de Reforestación y Educación Ambiental en '
          'Cerro Apante',
      subtitle: 'Reserva Natural Cerro Apante, Matagalpa · 24 may',
      category: RouteStopCategory.eco,
      latitude: 12.9,
      longitude: -85.9,
      dayNumber: 1,
      position: 1,
    ),
    const RouteStopModel(
      kind: RouteStopKind.business,
      sourceId: 'stress-test-id',
      title:
          'Complejo Ecoturístico y Balneario Familiar Laguna Escondida del '
          'Bosque Nuboso',
      subtitle: 'Región Autónoma de la Costa Caribe Norte · 240 km',
      category: RouteStopCategory.gastronomico,
      latitude: 12.13,
      longitude: -86.25,
      dayNumber: 2,
    ),
  ],
);

/// [_stressRoute] pero con fotos de portada y un nombre de creador
/// larguísimo, para forzar la cabecera de la tarjeta de Comunidad
/// ("Copiar ruta" + avatar + nombre) en el peor caso.
final _stressCommunityRoute = RouteModel(
  id: _stressRoute.id,
  ownerId: _stressRoute.ownerId,
  title: _stressRoute.title,
  days: _stressRoute.days,
  isPublic: _stressRoute.isPublic,
  createdAt: _stressRoute.createdAt,
  stops: _stressRoute.stops,
  imageUrls: const ['portada-1.jpg', 'portada-2.jpg', 'portada-3.jpg'],
  creatorName:
      'Fundación Nicaragua Verde para la Conservación de los Bosques Nubosos',
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
    // Desmonta antes de terminar y deja correr el reloj: las pantallas que se
    // suscriben a Realtime cierran su canal en dispose(), y ese cierre agenda
    // un timer de desconexión que, sin drenar, haría fallar el test por
    // "pending timers" aunque el layout esté bien.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
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

  testWidgets('EcoDetailScreen con contenido extremo no desborda', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      EcoDetailScreen(activity: _stressActivity),
      'EcoDetailScreen',
    );
  });

  testWidgets('EcoActivityCard con contenido extremo no desborda', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: EcoActivityCard(activity: _stressActivity, onTap: () {}),
        ),
      ),
      'EcoActivityCard',
    );
  });

  testWidgets('OrganizationProfileScreen con contenido extremo no desborda', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      OrganizationProfileScreen(organization: _stressOrganization),
      'OrganizationProfileScreen',
    );
  });

  testWidgets('PublicUserProfileScreen con contenido extremo no desborda', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      PublicUserProfileScreen(
        userId: 'stress-organizer-id',
        fallbackName: _stressActivity.organizerName,
      ),
      'PublicUserProfileScreen',
    );
  });

  testWidgets('CreateEcoActivityScreen no desborda en pantallas pequeñas', (
    tester,
  ) async {
    // Audita el formulario vacío: el peor caso de texto dinámico (nombres de
    // fundación en "Publicar como") ya lo cubre OrganizationProfileScreen, y
    // sin sesión la lista de fundaciones viene vacía de todas formas.
    await expectNoOverflow(
      tester,
      const CreateEcoActivityScreen(),
      'CreateEcoActivityScreen',
    );
  });

  testWidgets('PublicUserProfileScreen con foto de perfil no desborda', (
    tester,
  ) async {
    // Con avatar remoto: en el test la descarga falla y cae al placeholder,
    // que es justo el camino que antes dejaba el hueco en blanco.
    await expectNoOverflow(
      tester,
      const PublicUserProfileScreen(
        userId: 'stress-organizer-id',
        fallbackName: 'Bartolomé de las Casas y Fuentes Rodríguez de la Vega',
      ),
      'PublicUserProfileScreen (con foto)',
    );
  });

  testWidgets('CreateEcoActivityScreen en modo edición no desborda', (
    tester,
  ) async {
    // Precargado con los peores textos posibles: el formulario de edición
    // pinta el título/descripción/requisitos guardados dentro de los campos y
    // las pastillas, no solo placeholders cortos.
    await expectNoOverflow(
      tester,
      CreateEcoActivityScreen(existingActivity: _stressActivity),
      'CreateEcoActivityScreen (edición)',
    );
  });

  testWidgets('CreateOrganizationScreen no desborda en pantallas pequeñas', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      const CreateOrganizationScreen(),
      'CreateOrganizationScreen',
    );
  });

  testWidgets('RoutesMainScreen no desborda en pantallas pequeñas', (
    tester,
  ) async {
    // Sin sesión (como corre la suite) el listado viene vacío, así que esto
    // audita el estado vacío "Armá tu primera ruta".
    await expectNoOverflow(
      tester,
      const RoutesMainScreen(),
      'RoutesMainScreen',
    );
  });

  testWidgets('CreateRouteWizardScreen no desborda en pantallas pequeñas', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      const CreateRouteWizardScreen(),
      'CreateRouteWizardScreen',
    );
  });

  testWidgets('RouteDetailScreen con contenido extremo no desborda', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      RouteDetailScreen(route: _stressRoute),
      'RouteDetailScreen',
    );
  });

  testWidgets('RouteCard con contenido extremo no desborda', (tester) async {
    await expectNoOverflow(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: RouteCard(route: _stressRoute, onTap: () {}),
        ),
      ),
      'RouteCard',
    );
  });

  testWidgets(
    'RouteCard de Comunidad (cabecera + Copiar ruta) con contenido extremo '
    'no desborda',
    (tester) async {
      await expectNoOverflow(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RouteCard(
              route: _stressCommunityRoute,
              onTap: () {},
              showCreator: true,
              onCopy: () {},
            ),
          ),
        ),
        'RouteCard (Comunidad)',
      );
    },
  );

  testWidgets('FullScreenMapScreen con contenido extremo no desborda', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      FullScreenMapScreen(
        title: _stressCommunityRoute.stops.first.title,
        subtitle: _stressCommunityRoute.stops.first.subtitle,
        latitude: 12.13,
        longitude: -86.25,
        badge: RouteCategoryChip(
          category: _stressCommunityRoute.stops.first.category,
          compact: true,
        ),
      ),
      'FullScreenMapScreen',
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
