import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Regresión de "marco favoritos, cierro la app, la abro y Inicio no los
/// muestra hasta que entro a Perfil".
///
/// Inicio y Mapa solo escuchan `FavoritesService.idsNotifier`, que nace vacío y
/// solo se llenaba cuando alguien pedía los favoritos —y el único que lo hacía
/// al arrancar era Perfil, que el `PageView` no construye hasta visitarlo.
///
/// Sin sesión real la lectura va por la ruta de invitado (`SharedPreferences`),
/// que es la parte que no depende de Supabase; el defecto era el mismo: nadie
/// pedía la carga.
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
    FavoritesService().invalidate();
  });

  tearDown(() => FavoritesService().invalidate());

  /// Espera el trabajo asíncrono real (lectura de `SharedPreferences`) que el
  /// reloj falso de los tests no adelanta.
  Future<void> letAsyncWorkRun(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> mountMainLayout(WidgetTester tester, {Key? key}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MainLayout(key: key),
      ),
    );
    await letAsyncWorkRun(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    // Las pantallas con Realtime agendan un timer de desconexión al cerrar.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  }

  group('app recién abierta, sin pasar por el Perfil', () {
    testWidgets('Inicio ya tiene los favoritos cargados', (tester) async {
      SharedPreferences.setMockInitialValues({
        'favorite_ids_guest': ['laguna-de-apoyo', 'ometepe'],
      });
      FavoritesService().invalidate();
      expect(FavoritesService().idsNotifier.value, isEmpty);

      await mountMainLayout(tester);

      // Perfil no se construyó: lo único que pudo cargarlos fue el arranque.
      expect(find.byType(ProfileScreen), findsNothing);
      expect(FavoritesService().idsNotifier.value, {
        'laguna-de-apoyo',
        'ometepe',
      });

      await unmount(tester);
    });

    testWidgets('sin favoritos guardados no inventa ninguno ni avisa error', (
      tester,
    ) async {
      await mountMainLayout(tester);

      expect(FavoritesService().idsNotifier.value, isEmpty);
      expect(find.byType(SnackBar), findsNothing);

      await unmount(tester);
    });
  });

  group('cambio de cuenta y cierre de sesión', () {
    testWidgets('invalidar y abrir de nuevo recarga los favoritos', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'favorite_ids_guest': ['ometepe'],
      });
      FavoritesService().invalidate();
      await mountMainLayout(tester, key: const ValueKey('primera'));
      expect(FavoritesService().idsNotifier.value, {'ometepe'});

      // AuthService.signOut / switchAccount invalidan el singleton y la
      // navegación crea un MainLayout nuevo: eso es lo que se reproduce.
      FavoritesService().invalidate();
      expect(FavoritesService().idsNotifier.value, isEmpty);
      SharedPreferences.setMockInitialValues({
        'favorite_ids_guest': ['laguna-de-apoyo'],
      });

      await mountMainLayout(tester, key: const ValueKey('segunda'));
      expect(FavoritesService().idsNotifier.value, {'laguna-de-apoyo'});

      await unmount(tester);
    });

    test(
      'una lectura que termina tras invalidar no pisa a la cuenta nueva',
      () async {
        SharedPreferences.setMockInitialValues({
          'favorite_ids_guest': ['de-la-cuenta-anterior'],
        });
        FavoritesService().invalidate();

        // La lectura arranca, la sesión cambia antes de que termine…
        final pending = FavoritesService().preload();
        FavoritesService().invalidate();
        await pending;

        // …y su resultado se descarta: el notifier no se llenó con datos viejos
        // y la siguiente lectura sí carga normalmente.
        expect(FavoritesService().idsNotifier.value, isEmpty);
        expect(await FavoritesService().getFavoriteIds(), {
          'de-la-cuenta-anterior',
        });
      },
    );
  });

  group('FavoritesService.preload', () {
    test('devuelve true y nunca lanza', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_ids_guest': ['ometepe'],
      });
      FavoritesService().invalidate();

      expect(await FavoritesService().preload(), isTrue);
      expect(FavoritesService().idsNotifier.value, {'ometepe'});
      // Ya cargado: otra llamada es inmediata y no cambia nada.
      expect(await FavoritesService().preload(), isTrue);
    });

    test('dos cargas simultáneas comparten la misma lectura', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_ids_guest': ['ometepe'],
      });
      FavoritesService().invalidate();

      var notifications = 0;
      void onChange() => notifications++;
      FavoritesService().idsNotifier.addListener(onChange);
      addTearDown(
        () => FavoritesService().idsNotifier.removeListener(onChange),
      );

      final results = await Future.wait([
        FavoritesService().preload(),
        FavoritesService().preload(),
        FavoritesService().getFavoriteIds().then((_) => true),
      ]);

      expect(results, [true, true, true]);
      expect(notifications, 1, reason: 'publicó una sola vez');
    });

    test('el mensaje de error es el acordado, en español', () {
      expect(
        FavoritesService.loadFailedMessage,
        'No se pudieron cargar tus favoritos. Verifica tu internet e intenta '
        'de nuevo.',
      );
    });
  });
}
