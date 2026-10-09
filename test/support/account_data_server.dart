import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const placeA = '11111111-1111-4111-8111-111111111111';
const placeB = '22222222-2222-4222-8222-222222222222';

String accountSession(String id) => jsonEncode({
  'access_token': 'test-token-$id',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'test-refresh-$id',
  'user': {
    'id': id,
    'email': 'test@example.com',
    'app_metadata': {},
    'user_metadata': {},
    'aud': 'authenticated',
    'created_at': '2024-01-01T00:00:00Z',
  },
});

/// HTTP contract fixture; it does not pretend to validate deployed SQL or RLS.
class AccountDataServer {
  bool up = true;
  bool failWrites = false;
  Completer<void>? readGate;
  final requests = <http.Request>[];
  final favorites = <String, Set<String>>{};
  final trips = <String, List<Map<String, dynamic>>>{};
  final progress = <String, Map<String, dynamic>>{};
  final conversations = <String, Map<String, dynamic>>{};
  final postcards = <String, Map<String, dynamic>>{};

  http.Client get httpClient => MockClient((request) async {
    requests.add(request);
    http.Response reply(dynamic data, [int status = 200]) => http.Response(
      jsonEncode(data),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
    if (!up || (failWrites && request.method != 'GET')) {
      return reply({'code': 'PGRST000', 'message': 'server unavailable'}, 500);
    }
    final path = request.url.path;
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    final owner =
        request.headers['authorization']?.replaceFirst(
          'Bearer test-token-',
          '',
        ) ??
        userA;
    final filterOwner =
        request.url.queryParameters['user_id']?.replaceFirst('eq.', '') ??
        owner;
    final saved = favorites.putIfAbsent(owner, () => <String>{});
    if (path.endsWith('/user_favorites')) {
      final snapshot = [
        for (final id in favorites[filterOwner] ?? <String>{}) {'item_id': id},
      ];
      final gate = readGate;
      if (gate != null) await gate.future;
      return reply(snapshot);
    }
    if (path.endsWith('/rpc/set_business_favorite')) {
      final id = body['p_business_id'] as String;
      if (body['p_favorite'] == true) {
        saved.add(id);
      } else {
        saved.remove(id);
      }
      return reply(saved.contains(id));
    }
    if (path.endsWith('/rpc/business_favorite_count')) {
      return reply(
        favorites.values
            .where((ids) => ids.contains(body['p_business_id']))
            .length,
      );
    }
    if (path.endsWith('/rpc/record_passport_trip')) {
      final ownTrips = trips.putIfAbsent(owner, () => []);
      final id = body['p_trip_id'];
      if (ownTrips.any((t) => t['trip_id'] == id)) return reply(false);
      ownTrips.add({
        'trip_id': id,
        'started_at': body['p_started_at'],
        'completed_at': body['p_completed_at'],
        'postcard': {
          ...postcards[body['p_business_id']]!,
          'sealed_at': body['p_completed_at'],
        },
      });
      return reply(true);
    }
    if (path.endsWith('/passport_trips')) {
      return reply(trips[filterOwner] ?? []);
    }
    if (path.endsWith('/route_visit_progress')) {
      final route = request.url.queryParameters['route_id']?.replaceFirst(
        'eq.',
        '',
      );
      if (request.method == 'GET') {
        return reply(
          progress.values
              .where(
                (r) => r['user_id'] == filterOwner && r['route_id'] == route,
              )
              .toList(),
        );
      }
      if (request.method == 'POST') {
        progress['${body['user_id']}:${body['route_id']}:${body['visit_key']}'] =
            Map<String, dynamic>.from(body);
        return reply(body, 201);
      }
      final key = request.url.queryParameters['visit_key']?.replaceFirst(
        'eq.',
        '',
      );
      progress.remove('$filterOwner:$route:$key');
      return http.Response('', 204, request: request);
    }
    if (path.endsWith('/assistant_conversations')) {
      if (request.method == 'GET') {
        return reply(
          conversations.values
              .where((r) => r['user_id'] == filterOwner)
              .toList(),
        );
      }
      if (request.method == 'POST') {
        conversations[body['id']] = Map<String, dynamic>.from(body);
        return reply({'id': body['id']}, 201);
      }
      final id = request.url.queryParameters['id']?.replaceFirst('eq.', '');
      conversations.removeWhere(
        (key, r) => r['user_id'] == filterOwner && (id == null || key == id),
      );
      return http.Response('', 204, request: request);
    }
    return reply([]);
  });

  SupabaseClient newClient() => SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    httpClient: httpClient,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}
