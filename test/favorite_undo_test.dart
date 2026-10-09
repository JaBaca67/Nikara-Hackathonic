import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/remote_user_data_service.dart';
import 'package:nikara_app/shared/widgets/favorite_toggle.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _user = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _place = '11111111-1111-4111-8111-111111111111';

const _removed = 'Quitado de favoritos';
const _undo = 'Deshacer';

/// Sesión persistida con la forma que guarda `supabase_flutter`, vigente una
/// hora: al iniciar se restaura sin tocar la red.
String _sessionJson() => jsonEncode({
  'access_token': 'token-falso',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'refresh-falso',
  'user': {
    'id': _user,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2024-01-01T00:00:00Z',
  },
});

/// "Servidor" simulado de `user_favorites`: con [up] falso las escrituras
/// fallan como sin conexión y las lecturas con un error 500 (que `postgrest`
/// no reintenta; un corte de red en un GET tarda unos 7 s en rendirse).
class _FakeServer {
  bool up = true;
  Set<String> favorites = {};
  int writes = 0;

  http.Client get client => MockClient((request) async {
    final isRead = request.method == 'GET';
    if (request.url.path.endsWith('/rpc/set_business_favorite')) {
      if (!up) throw http.ClientException('Offline');
      writes++;
      final params = jsonDecode(request.body);
      if (params['p_favorite'] == true) {
        favorites.add(params['p_business_id']);
      } else {
        favorites.remove(params['p_business_id']);
      }
      return http.Response(
        jsonEncode(params['p_favorite']),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    if (!request.url.path.endsWith('/user_favorites') || !up) {
      if (!isRead && request.url.path.endsWith('/user_favorites')) {
        throw http.ClientException('Sin conexión (simulada)');
      }
      return http.Response(
        jsonEncode({'message': 'no disponible', 'code': 'PGRST000'}),
        500,
        request: request,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
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
    writes++;
    if (request.method == 'POST') {
      favorites.add(_place);
      return http.Response('', 201, request: request);
    }
    favorites.remove(_place);
    return http.Response('', 204, request: request);
  });
}

void main() {
  final server = _FakeServer();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    RemoteUserDataService.realtimeEnabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel("com.llfbandit.app_links/events"),
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({
      'sb-example-auth-token': _sessionJson(),
    });
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
      ..writes = 0;
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(_sessionJson());
    FavoritesService().resetForTesting();
  });

  tearDown(() => FavoritesService().invalidate());

  /// Pantalla mínima con un botón que alterna el favorito como lo hacen las
  /// tarjetas reales, y un corazón que sigue a `idsNotifier`.
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ValueListenableBuilder<Set<String>>(
                  valueListenable: FavoritesService().idsNotifier,
                  builder: (_, ids, _) => Icon(
                    ids.contains(_place)
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                ),
                TextButton(
                  onPressed: () => toggleFavoriteWithFeedback(context, _place),
                  child: const Text('corazón'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await FavoritesService().preload();
    await tester.pump();
  }

  /// El servicio escribe en `SharedPreferences` y la red simulada responde
  /// fuera del reloj falso: se deja correr trabajo real entre cuadros.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  bool isFavorite() => FavoritesService().idsNotifier.value.contains(_place);

  testWidgets('marcar un favorito no muestra ningún aviso', (tester) async {
    await pumpHost(tester);

    await tapAndSettle(tester, find.text('corazón'));

    expect(isFavorite(), isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('quitarlo avisa "Quitado de favoritos" con "Deshacer"', (
    tester,
  ) async {
    server.favorites = {_place};
    FavoritesService().invalidate();
    await pumpHost(tester);
    expect(isFavorite(), isTrue);

    await tapAndSettle(tester, find.text('corazón'));

    expect(isFavorite(), isFalse);
    expect(find.text(_removed), findsOneWidget);
    expect(find.text(_undo), findsOneWidget);
  });

  testWidgets('"Deshacer" lo vuelve a marcar y cierra el aviso', (
    tester,
  ) async {
    server.favorites = {_place};
    FavoritesService().invalidate();
    await pumpHost(tester);
    await tapAndSettle(tester, find.text('corazón'));
    expect(isFavorite(), isFalse);

    await tapAndSettle(tester, find.text(_undo));

    expect(isFavorite(), isTrue);
    expect(server.favorites, {_place});
    expect(find.text(_removed), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'si "Deshacer" falla, avisa en español y el corazón sigue vacío',
    (tester) async {
      server.favorites = {_place};
      FavoritesService().invalidate();
      await pumpHost(tester);
      await tapAndSettle(tester, find.text('corazón'));
      expect(isFavorite(), isFalse);

      server.up = false;
      await tapAndSettle(tester, find.text(_undo));

      expect(isFavorite(), isFalse);
      expect(find.text(FavoritesService.offlineToggleMessage), findsOneWidget);
      expect(find.text(_removed), findsNothing);
    },
  );

  testWidgets('si quitarlo falla, solo sale el error: nada de "Quitado"', (
    tester,
  ) async {
    server.favorites = {_place};
    FavoritesService().invalidate();
    await pumpHost(tester);

    server.up = false;
    await tapAndSettle(tester, find.text('corazón'));

    expect(isFavorite(), isTrue, reason: 'el corazón se queda como estaba');
    expect(find.text(FavoritesService.loadFailedMessage), findsOneWidget);
    expect(find.text(_removed), findsNothing);
    expect(find.text(_undo), findsNothing);
  });

  testWidgets('"Deshacer" no hace nada si ya lo volvió a marcar a mano', (
    tester,
  ) async {
    server.favorites = {_place};
    FavoritesService().invalidate();
    await pumpHost(tester);
    await tapAndSettle(tester, find.text('corazón'));
    expect(isFavorite(), isFalse);

    // La persona lo vuelve a marcar sin usar el aviso…
    await FavoritesService().toggleFavorite(_place);
    expect(isFavorite(), isTrue);
    final writesBefore = server.writes;

    // …y el "Deshacer" que seguía a la vista no lo debe quitar otra vez.
    await tapAndSettle(tester, find.text(_undo));

    expect(isFavorite(), isTrue);
    expect(server.writes, writesBefore);
  });
}
