import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'support/account_data_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountDataServer server;
  late SupabaseClient client;
  final postcard = {
    'id': placeA,
    'title': 'Negocio real',
    'region': 'Granada',
    'message': 'Descripción',
    'category': 'Restaurante',
    'address': '',
    'schedules': '',
    'sealed_at': '2026-10-06T18:20:00Z',
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'completed_business_trips_v1_$userA': jsonEncode([
        {
          'id': 'trip-a',
          'started_at': '2026-10-06T18:00:00Z',
          'postcard': postcard,
        },
      ]),
      'route_travel_v1:$userA:$placeB': jsonEncode({
        '1:business:$placeA': 'visited',
      }),
      'completed_business_trips_v1_$userB': 'unrelated account',
    });
    server = AccountDataServer();
    server.postcards[placeA] = postcard;
    client = server.newClient();
    await client.auth.recoverSession(accountSession(userA));
  });
  tearDown(() => client.dispose());
  test(
    'confirmed transfers remove only data belonging to this account',
    () async {
      await LocalProfileExtrasService().migrateAccountData(client: client);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('completed_business_trips_v1_$userA'), isFalse);
      expect(prefs.containsKey('route_travel_v1:$userA:$placeB'), isFalse);
      expect(
        prefs.getString('completed_business_trips_v1_$userB'),
        'unrelated account',
      );
      expect(server.trips[userA], hasLength(1));
      expect(server.progress, hasLength(1));
    },
  );
  test('network failure preserves legacy data for a later transfer', () async {
    server.failWrites = true;
    await expectLater(
      LocalProfileExtrasService().migrateAccountData(client: client),
      throwsA(isA<PostgrestException>()),
    );
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'completed_business_trips_v1_$userA',
      ),
      isTrue,
    );
    server.failWrites = false;
    await LocalProfileExtrasService().migrateAccountData(client: client);
    expect(server.trips[userA], hasLength(1));
  });
}
