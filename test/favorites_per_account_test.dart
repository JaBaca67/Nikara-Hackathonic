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
      'favorite_ids_guest': [placeB],
      'favorite_cache_$userA': [placeB],
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
    'server confirmation survives a second device and does not write preferences',
    () async {
      expect(await service.toggleFavorite(placeA), isTrue);
      final second = server.newClient();
      await second.auth.recoverSession(accountSession(userA));
      final otherDevice = FavoritesService.forTesting(second);
      expect(await otherDevice.getFavoriteIds(), {placeA});
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'favorite_cache_$userA',
        ),
        [placeB],
      );
      expect(await otherDevice.toggleFavorite(placeA), isFalse);
      expect(await service.getFavoriteIds(), isEmpty);
      otherDevice.invalidate();
      await second.dispose();
    },
  );
  test(
    'switching account discards the prior snapshot and filters by actual user',
    () async {
      await service.toggleFavorite(placeA);
      await client.auth.recoverSession(accountSession(userB));
      expect(await service.getFavoriteIds(), isEmpty);
      await service.toggleFavorite(placeB);
      expect(server.favorites[userA], {placeA});
      expect(server.favorites[userB], {placeB});
    },
  );
  test(
    'explicit add is idempotent even when another device has already added it',
    () async {
      server.favorites[userA] = {placeA};
      expect(await service.setFavorite(placeA, true), isTrue);
      expect(await service.setFavorite(placeA, true), isTrue);
      expect(server.favorites[userA], {placeA});
      expect(await service.countFavoritesForBusiness(placeA), 1);
    },
  );
  test(
    'owner count includes distinct users rather than the current private list',
    () async {
      server.favorites[userA] = {placeA};
      server.favorites[userB] = {placeA};
      expect(await service.countFavoritesForBusiness(placeA), 2);
      expect(
        server.requests.last.url.path,
        endsWith('/rpc/business_favorite_count'),
      );
    },
  );
  test(
    'guest and demo IDs cannot be saved locally or sent to the database',
    () async {
      await expectLater(
        service.toggleFavorite('ometepe'),
        throwsA(isA<FavoritesServiceException>()),
      );
      await client.auth.signOut(scope: SignOutScope.local);
      expect(await service.getFavoriteIds(), isEmpty);
      await expectLater(
        service.toggleFavorite(placeA),
        throwsA(isA<FavoritesServiceException>()),
      );
      expect(server.favorites.values.every((ids) => ids.isEmpty), isTrue);
    },
  );
}
