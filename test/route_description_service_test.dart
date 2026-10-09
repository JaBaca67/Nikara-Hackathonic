import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/routes/data/route_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';

void main() {
  const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const routeId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const sourceUrl = 'https://ciudadcreativa.managua.gob.ni/circuitos-creativos';
  final writes = <http.Request>[];
  final reads = <http.Request>[];
  var missingDescription = false;
  final existing = <String, dynamic>{
    'id': routeId,
    'owner_id': owner,
    'title': 'Xolotlán',
    'description': 'Descripción guardada en el servidor.',
    'source_url': sourceUrl,
    'days': 1,
    'is_public': true,
    'created_at': '2026-10-08T00:00:00Z',
    'public_profiles': {
      'id': owner,
      'full_name': 'Creador de la ruta',
      'avatar_url': 'https://example.com/avatar.jpg',
    },
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object body = [];
        var status = 200;
        if (request.method == 'POST' && request.url.path.endsWith('/routes')) {
          writes.add(request);
          if (missingDescription) {
            status = 400;
            body = {
              'code': 'PGRST204',
              'message':
                  "Could not find the 'description' column of 'routes' in the schema cache",
            };
          } else {
            body = {
              ...existing,
              'catalog_name': null,
              ...jsonDecode(request.body) as Map<String, dynamic>,
            };
          }
        } else if (request.method == 'PATCH') {
          writes.add(request);
        } else if (request.url.path.endsWith('/routes')) {
          reads.add(request);
          final select = request.url.queryParameters['select'] ?? '';
          // El esquema real tiene dos relaciones: creador y progreso de
          // visitantes. PostgREST rechaza elegir el perfil sin indicar la FK.
          if (!select.contains('public_profiles!routes_owner_id_fkey(')) {
            status = 300;
            body = {
              'code': 'PGRST201',
              'message':
                  'More than one relationship between routes and public_profiles',
            };
          } else {
            body =
                request.url.queryParameters['is_public'] == 'eq.true' ||
                    request.url.queryParameters.containsKey('owner_id')
                ? [existing]
                : existing;
          }
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'refresh_token': 'test-refresh',
        'expires_in': 3600,
        'expires_at':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'user': {
          'id': owner,
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  setUp(() {
    writes.clear();
    reads.clear();
    missingDescription = false;
    existing['owner_id'] = owner;
    existing.remove('catalog_name');
    existing['public_profiles'] = {
      'id': owner,
      'full_name': 'Creador de la ruta',
      'avatar_url': 'https://example.com/avatar.jpg',
    };
  });
  tearDownAll(() => Supabase.instance.dispose());

  test(
    'propias, comunidad y detalle cargan al creador y no al visitante',
    () async {
      final mine = await RouteService().getMyRoutes();
      final community = await RouteService().getPublicRoutes();
      final detail = await RouteService().getRouteById(routeId);

      for (final route in [mine.single, community.single, detail!]) {
        expect(route.creatorName, 'Creador de la ruta');
        expect(route.creatorAvatarUrl, 'https://example.com/avatar.jpg');
      }
      expect(reads, hasLength(3));
      expect(reads.first.url.queryParameters['owner_id'], 'eq.$owner');
    },
  );

  test('un perfil oculto no impide cargar la ruta ni sus paradas', () async {
    existing['public_profiles'] = null;
    final routes = await RouteService().getPublicRoutes();
    expect(routes.single.id, routeId);
    expect(routes.single.creatorName, isNull);
    expect(routes.single.creatorDisplayName, 'Alguien de Níkara');
  });

  test('Comunidad incluye las rutas públicas de la cuenta promotora', () async {
    final routes = await RouteService().getPublicRoutes();
    expect(routes.single.ownerId, owner);
    expect(reads.single.url.queryParameters['is_public'], 'eq.true');
    expect(reads.single.url.queryParameters.containsKey('owner_id'), isFalse);
  });

  test(
    'catálogo sin dueño se ve en Comunidad y se copia como ruta personal',
    () async {
      existing['owner_id'] = null;
      existing['catalog_name'] = 'Circuito Creativo Xolotlán';
      final routes = await RouteService().getPublicRoutes();
      expect(routes.single.isCatalog, isTrue);
      expect(routes.single.isOwnedBy(owner), isFalse);
      final clone = await RouteService().cloneRoute(routes.single);
      final payload = jsonDecode(writes.single.body) as Map<String, dynamic>;
      expect(payload['owner_id'], owner);
      expect(payload['is_public'], isFalse);
      expect(payload.containsKey('catalog_name'), isFalse);
      expect(payload['cloned_from_route_id'], routeId);
      expect(clone.description, existing['description']);
      expect(clone.sourceUrl, sourceUrl);
      expect(clone.isCatalog, isFalse);
    },
  );

  test('crear guarda la descripción sin espacios exteriores', () async {
    final route = await RouteService().createRoute(
      title: 'Mi ruta',
      description: '  Mi descripción  ',
      days: 1,
      isPublic: false,
    );
    expect(route.description, 'Mi descripción');
    expect(jsonDecode(writes.single.body)['description'], 'Mi descripción');
  });

  test('editar permite borrar la descripción y filtra por dueño', () async {
    await RouteService().updateRoute(routeId, description: '');
    expect(jsonDecode(writes.single.body)['description'], '');
    expect(writes.single.url.queryParameters['owner_id'], 'eq.$owner');
    writes.clear();
    await RouteService().updateRoute(routeId, title: 'Otro título');
    expect(jsonDecode(writes.single.body).containsKey('description'), isFalse);
  });

  test(
    'copiar conserva la descripción actual del servidor y la fuente',
    () async {
      final stale = RouteModel.fromRow({
        ...existing,
        'description': 'Descripción antigua',
      });
      final clone = await RouteService().cloneRoute(stale);
      final body = jsonDecode(writes.single.body);
      expect(clone.description, existing['description']);
      expect(clone.sourceUrl, sourceUrl);
      expect(body['cloned_from_route_id'], routeId);
      expect(body['is_public'], isFalse);
    },
  );

  test(
    'una migración faltante no elimina silenciosamente la descripción',
    () async {
      missingDescription = true;
      await expectLater(
        RouteService().createRoute(
          title: 'Mi ruta',
          description: 'Conservar',
          days: 1,
          isPublic: false,
        ),
        throwsA(isA<RouteServiceException>()),
      );
      expect(writes, hasLength(1));
    },
  );

  test(
    'rechaza descripciones superiores al límite antes de escribir',
    () async {
      await expectLater(
        RouteService().createRoute(
          title: 'Mi ruta',
          description: 'x' * 501,
          days: 1,
          isPublic: false,
        ),
        throwsA(isA<RouteServiceException>()),
      );
      expect(writes, isEmpty);
    },
  );
}
