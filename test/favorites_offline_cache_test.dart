import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'support/account_data_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountDataServer server;
  late SupabaseClient client;
  late FavoritesService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'favorite_cache_$userA': [placeA],
    });
    server = AccountDataServer();
    client = server.newClient();
    await client.auth.recoverSession(accountSession(userA));
    service = FavoritesService.forTesting(client);
  });
  tearDown(() async {
    service.invalidate();
    await client.dispose();
  });
  test(
    'offline reads report failure and never adopt old disk caches',
    () async {
      server.up = false;
      expect(await service.preload(), isFalse);
      expect(service.idsNotifier.value, isEmpty);
      await expectLater(
        service.getFavoriteIds(),
        throwsA(isA<FavoritesServiceException>()),
      );
      server.up = true;
      server.favorites[userA] = {placeB};
      expect(await service.getFavoriteIds(), {placeB});
    },
  );
  test(
    'failed writes do not change the heart and the queue permits retry',
    () async {
      await service.preload();
      server.failWrites = true;
      await expectLater(
        service.toggleFavorite(placeA),
        throwsA(isA<FavoritesServiceException>()),
      );
      expect(service.idsNotifier.value, isEmpty);
      expect(server.favorites[userA], isEmpty);
      server.failWrites = false;
      expect(await service.toggleFavorite(placeA), isTrue);
    },
  );
  test(
    'a late read from the previous account cannot replace the new snapshot',
    () async {
      server.favorites[userA] = {placeA};
      server.readGate = Completer<void>();
      final oldRead = service.preload();
      while (server.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await client.auth.recoverSession(accountSession(userB));
      service.invalidate();
      final gate = server.readGate!;
      server.readGate = null;
      gate.complete();
      expect(await oldRead, isFalse);
      expect(await service.getFavoriteIds(), isEmpty);
    },
  );
  test(
    'two concurrent reads share a request and later reads fetch remote changes',
    () async {
      server.favorites[userA] = {placeA};
      expect(await Future.wait([service.preload(), service.preload()]), [
        true,
        true,
      ]);
      expect(server.requests, hasLength(1));
      server.favorites[userA]!.add(placeB);
      expect(await service.getFavoriteIds(), {placeA, placeB});
    },
  );
}
