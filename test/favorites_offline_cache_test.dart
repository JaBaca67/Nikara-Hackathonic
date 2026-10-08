import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _fav1 = '11111111-1111-4111-8111-111111111111';
const _fav2 = '22222222-2222-4222-8222-222222222222';

const _sessionKey = 'sb-example-auth-token';

/// Sesión persistida con la forma que guarda `supabase_flutter`, vigente por
/// una hora: al iniciar se restaura sin tocar la red.
String _sessionJson(String userId) => jsonEncode({
  'access_token': 'token-falso',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'refresh-falso',
  'user': {
    'id': userId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2024-01-01T00:00:00Z',
  },
});

/// Estado del "servidor" simulado: [up] decide si responde y [favorites] es lo
/// que hay en `user_favorites`.
///
/// Cuando [up] es falso, las lecturas (GET) fallan con un error 500 y las
/// escrituras (POST/DELETE) con un corte de conexión. No es casual: `postgrest`
/// reintenta cada GET que falla por red con esperas de 1, 2 y 4 s (unos 7 s
/// por lectura, aunque se desactive `retryEnabled`), y un 500 no se reintenta.
/// Para el servicio da igual: cualquier excepción es "lectura fallida".
class _FakeServer {
  bool up = true;
  Set<String> favorites = {};

  /// Cuántas peticiones a `user_favorites` llegaron a intentarse.
  int favoritesRequests = 0;

  http.Response _serverError(http.BaseRequest request) => http.Response(
    jsonEncode({'message': 'servidor caído (simulado)', 'code': 'PGRST000'}),
    500,
    request: request,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Client get client => MockClient((request) async {
    final isRead = request.method == 'GET';
    if (!up) {
      if (request.url.path.endsWith('/user_favorites')) favoritesRequests++;
      if (!isRead) throw http.ClientException('Sin conexión (simulada)');
      return _serverError(request);
    }
    if (request.url.path.endsWith('/user_favorites')) {
      favoritesRequests++;
      if (isRead) {
        return http.Response(
          jsonEncode([
            for (final id in favorites) {'item_id': id},
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        '',
        request.method == 'POST' ? 201 : 204,
        request: request,
      );
    }
    // El resto de tablas (negocios, perfiles…) no están simuladas: responden
    // con error. Lo que importa en estas pruebas son los favoritos.
    return _serverError(request);
  });
}

void main() {
  final server = _FakeServer();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({_sessionKey: _sessionJson(_userA)});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: server.client,
    );
  });

  setUp(() async {
    server
      ..up = true
      ..favorites = {}
      ..favoritesRequests = 0;
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(_sessionJson(_userA));
    FavoritesService().invalidate();
  });

  tearDown(() => FavoritesService().invalidate());

  void seedCache(Map<String, List<String>> byUser) {
    SharedPreferences.setMockInitialValues({
      for (final entry in byUser.entries)
        'favorite_cache_${entry.key}': entry.value,
    });
    FavoritesService().invalidate();
  }

  Future<List<String>?> cacheOf(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favorite_cache_$userId');
  }

  group('sin internet: copia local por usuario', () {
    test(
      'los favoritos guardados aparecen y no se marca como cargado',
      () async {
        seedCache({
          _userA: [_fav1],
        });
        server.up = false;

        expect(await FavoritesService().preload(), isFalse);
        expect(FavoritesService().idsNotifier.value, {_fav1});

        // No quedó "cargado": otra lectura vuelve a consultar al servidor.
        final before = server.favoritesRequests;
        expect(await FavoritesService().preload(), isFalse);
        expect(server.favoritesRequests, greaterThan(before));
        expect(FavoritesService().idsNotifier.value, {_fav1});
      },
    );

    test('sin copia queda vacío, como antes', () async {
      server.up = false;

      expect(await FavoritesService().preload(), isFalse);
      expect(FavoritesService().idsNotifier.value, isEmpty);
    });

    test('con otra cuenta no aparecen los favoritos de la anterior', () async {
      seedCache({
        _userA: [_fav1],
      });
      server.up = false;
      await FavoritesService().preload();
      expect(FavoritesService().idsNotifier.value, {_fav1});

      // Cambio de cuenta: igual que AuthService.switchAccount, que cambia la
      // sesión e invalida el servicio.
      await Supabase.instance.client.auth.recoverSession(_sessionJson(_userB));
      FavoritesService().invalidate();
      expect(FavoritesService().idsNotifier.value, isEmpty);

      await FavoritesService().preload();
      expect(
        FavoritesService().idsNotifier.value,
        isEmpty,
        reason: 'la cuenta B no tiene copia y no debe heredar la de A',
      );

      // Y con copia propia ve solo la suya.
      seedCache({
        _userA: [_fav1],
        _userB: [_fav2],
      });
      await FavoritesService().preload();
      expect(FavoritesService().idsNotifier.value, {_fav2});
    });

    test(
      'al volver la lectura remota se actualiza y reemplaza la copia',
      () async {
        seedCache({
          _userA: [_fav1],
        });
        server
          ..up = false
          ..favorites = {_fav2};
        await FavoritesService().preload();
        expect(FavoritesService().idsNotifier.value, {_fav1});

        server.up = true;
        expect(await FavoritesService().preload(), isTrue);

        expect(FavoritesService().idsNotifier.value, {_fav2});
        expect(await cacheOf(_userA), [_fav2]);
      },
    );

    test('cada lectura buena guarda la copia de ese usuario', () async {
      server.favorites = {_fav1, _fav2};

      expect(await FavoritesService().preload(), isTrue);

      expect(await cacheOf(_userA), unorderedEquals([_fav1, _fav2]));
      expect(await cacheOf(_userB), isNull);
    });

    test(
      'getFavoriteIds avisa del fallo pero deja la copia en pantalla',
      () async {
        seedCache({
          _userA: [_fav1],
        });
        server.up = false;

        await expectLater(
          FavoritesService().getFavoriteIds(),
          throwsA(
            isA<FavoritesServiceException>().having(
              (e) => e.message,
              'message',
              FavoritesService.loadFailedMessage,
            ),
          ),
        );
        expect(FavoritesService().idsNotifier.value, {_fav1});
      },
    );
  });

  group('marcar o quitar un favorito', () {
    test(
      'sin internet no finge: avisa y deja el corazón como estaba',
      () async {
        server.favorites = {_fav1};
        await FavoritesService().preload();
        expect(FavoritesService().idsNotifier.value, {_fav1});

        server.up = false;
        await expectLater(
          FavoritesService().toggleFavorite(_fav2),
          throwsA(
            isA<FavoritesServiceException>().having(
              (e) => e.message,
              'message',
              'Sin conexión. No se pudo actualizar tu favorito.',
            ),
          ),
        );

        expect(FavoritesService().idsNotifier.value, {_fav1});
        expect(await cacheOf(_userA), [_fav1]);
      },
    );

    test('quitar sin internet tampoco lo quita de la vista', () async {
      server.favorites = {_fav1};
      await FavoritesService().preload();

      server.up = false;
      await expectLater(
        FavoritesService().toggleFavorite(_fav1),
        throwsA(isA<FavoritesServiceException>()),
      );
      expect(FavoritesService().idsNotifier.value, {_fav1});
    });

    test('con internet actualiza la vista y la copia', () async {
      await FavoritesService().preload();

      expect(await FavoritesService().toggleFavorite(_fav2), isTrue);
      expect(FavoritesService().idsNotifier.value, {_fav2});
      expect(await cacheOf(_userA), [_fav2]);

      expect(await FavoritesService().toggleFavorite(_fav2), isFalse);
      expect(FavoritesService().idsNotifier.value, isEmpty);
      expect(await cacheOf(_userA), isEmpty);
    });
  });

  group('sin aviso y con reintento desde las pantallas', () {
    Future<void> letAsyncWorkRun(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    }

    Future<void> mount(WidgetTester tester, Widget home) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: home),
      );
      await letAsyncWorkRun(tester);
    }

    testWidgets('al abrir sin internet carga lo que puede y no muestra aviso', (
      tester,
    ) async {
      seedCache({
        _userA: [_fav1],
      });
      server.up = false;
      final callsBefore = FavoritesService().preloadCallCount;

      await mount(tester, const MainLayout());

      expect(FavoritesService().preloadCallCount, callsBefore + 1);
      expect(FavoritesService().idsNotifier.value, {_fav1});
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(FavoritesService.loadFailedMessage), findsNothing);

      await unmount(tester);
    });

    testWidgets('el "Reintentar" de Inicio vuelve a llamar a preload()', (
      tester,
    ) async {
      seedCache({
        _userA: [_fav1],
      });
      server.up = false;
      await mount(tester, const HomeScreen());
      expect(find.text('Reintentar'), findsOneWidget);

      final callsBefore = FavoritesService().preloadCallCount;
      server.up = true;
      server.favorites = {_fav2};
      await tester.tap(find.text('Reintentar'));
      await letAsyncWorkRun(tester);

      expect(FavoritesService().preloadCallCount, callsBefore + 1);
      // Y al volver la señal los favoritos del servidor reemplazan la copia.
      expect(FavoritesService().idsNotifier.value, {_fav2});

      await unmount(tester);
    });

    testWidgets('el "Reintentar" de Perfil vuelve a llamar a preload()', (
      tester,
    ) async {
      seedCache({
        _userA: [_fav1],
      });
      server.up = false;
      await mount(tester, const ProfileScreen());
      expect(find.text('Reintentar'), findsOneWidget);

      final callsBefore = FavoritesService().preloadCallCount;
      await tester.tap(find.text('Reintentar'));
      await letAsyncWorkRun(tester);

      expect(FavoritesService().preloadCallCount, greaterThan(callsBefore));

      await unmount(tester);
    });
  });
}
