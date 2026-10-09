import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/account_data_server.dart';
import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/services/passport_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const business = BusinessModel(
    id: placeA,
    name: 'Restaurante El Zaguán',
    category: 'Restaurante',
    description: 'Gastronomía nicaragüense en Granada.',
    city: 'Granada',
    locationText: 'Detrás de la Catedral de Granada',
    latitude: 11.9293,
    longitude: -85.9525,
    contactPhone: '',
    hostName: '',
    localImagePaths: ['https://example.com/zaguan.jpg'],
    reviewStatus: ReviewStatus.aprobado,
  );
  final start = DateTime.utc(2026, 10, 6, 18);
  final arrival = start.add(const Duration(minutes: 20));
  late String? currentUser;
  late PassportService service;
  late AccountDataServer server;
  late SupabaseClient client;
  PassportService makeService([
    Future<void> Function(String, PassportCollection)? callback,
  ]) => PassportService.forTesting(() => currentUser, callback, client);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    currentUser = userA;
    server = AccountDataServer();
    client = server.newClient();
    await client.auth.recoverSession(accountSession(userA));
    server.postcards[placeA] = TravelPostcard.fromBusiness(business).toJson();
    service = makeService();
  });

  tearDown(() => client.dispose());

  Future<TravelPostcard> complete({
    String tripId = 'trip-1',
    String owner = userA,
    BusinessModel destination = business,
    DateTime? completedAt,
  }) => service.recordCompletedTrip(
    tripId: tripId,
    ownerId: owner,
    business: destination,
    startedAt: start,
    completedAt: completedAt ?? arrival,
  );

  test(
    'arrival snapshot and timestamp survive reopening the service',
    () async {
      expect((await service.getCollection()).postcards, isEmpty);
      final stamped = await complete();
      expect(stamped.sealedAt, arrival);
      final reopened = makeService();
      final collection = await reopened.getCollection();
      expect(collection.trips, hasLength(1));
      final saved = collection.postcards.single;
      expect(saved.sealedAt, arrival);
      expect(saved.title, business.name);
      expect(saved.imagePath, business.localImagePaths.first);
      expect(saved.address, business.locationText);
      expect(saved.toJson()['sealed_at'], arrival.toIso8601String());
    },
  );

  test(
    'retry is idempotent; a second trip preserves the first postcard seal',
    () async {
      await complete();
      await complete();
      expect((await service.getCollection()).trips, hasLength(1));
      final repeated = await complete(
        tripId: 'trip-2',
        destination: business.copyWith(name: 'Updated business name'),
        completedAt: arrival.add(const Duration(days: 1)),
      );
      final collection = await service.getCollection();
      expect(collection.trips, hasLength(2));
      expect(collection.postcards, hasLength(1));
      expect(repeated.sealedAt, arrival);
      expect(repeated.title, business.name);
    },
  );

  test('concurrent completions are serialized without losing trips', () async {
    await Future.wait([
      complete(tripId: 'trip-a'),
      complete(tripId: 'trip-b'),
      complete(tripId: 'trip-c'),
    ]);
    expect((await service.getCollection()).trips, hasLength(3));
    expect((await service.getCollection()).postcards, hasLength(1));
  });

  test(
    'collections are isolated by account and unavailable after logout',
    () async {
      await complete();
      currentUser = userB;
      await client.auth.recoverSession(accountSession(userB));
      expect((await service.getCollection()).trips, isEmpty);
      await expectLater(complete(), throwsA(isA<PassportServiceException>()));
      await complete(owner: userB, tripId: 'trip-b');
      expect((await service.getCollection()).trips.single.id, 'trip-b');
      currentUser = null;
      expect((await service.getCollection()).postcards, isEmpty);
      currentUser = userA;
      await client.auth.recoverSession(accountSession(userA));
      expect((await service.getCollection()).trips.single.id, 'trip-1');
    },
  );

  test(
    'invalid completions do not write; the queue recovers after an error',
    () async {
      await expectLater(
        complete(completedAt: start.subtract(const Duration(seconds: 1))),
        throwsA(isA<PassportServiceException>()),
      );
      await expectLater(
        complete(
          destination: business.copyWith(reviewStatus: ReviewStatus.pendiente),
        ),
        throwsA(isA<PassportServiceException>()),
      );
      expect((await service.getCollection()).trips, isEmpty);
      await complete();
      expect((await service.getCollection()).postcards, hasLength(1));
    },
  );

  test(
    'server failure is reported, preserves collection and permits retry',
    () async {
      server.up = false;
      await expectLater(
        service.getCollection(),
        throwsA(isA<PassportServiceException>()),
      );
      await expectLater(complete(), throwsA(isA<PassportServiceException>()));
      expect(server.trips, isEmpty);
      server.up = true;
      await complete();
      expect((await service.getCollection()).trips, hasLength(1));
    },
  );

  test(
    'completed trips publish persisted progress once and use real arrival dates',
    () async {
      final progress = <PassportCollection>[];
      service = makeService((owner, collection) async {
        expect(owner, currentUser);
        expect(
          (await service.getCollection()).trips.length,
          collection.trips.length,
        );
        progress.add(collection);
      });
      await complete();
      await complete();
      await complete(
        tripId: 'trip-2',
        completedAt: arrival.add(const Duration(hours: 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(progress.map((collection) => collection.trips.length), [1, 2]);
      expect(progress.last.notificationTrips.last, {
        'trip_id': 'trip-2',
        'business_id': business.id,
        'started_at': start.toIso8601String(),
        'completed_at': arrival.add(const Duration(hours: 1)).toIso8601String(),
      });
      expect(progress.last.postcards, hasLength(1));
    },
  );

  test('notification failure never loses the earned postcard', () async {
    service = makeService((_, _) async {
      throw Exception('Entrega no disponible');
    });
    final postcard = await complete();
    await Future<void>.delayed(Duration.zero);
    expect(postcard.isStamped, isTrue);
    expect((await service.getCollection()).postcards, hasLength(1));
  });

  test('invalid trips do not publish progress', () async {
    var notifications = 0;
    service = makeService((_, _) async {
      notifications++;
    });
    await expectLater(
      complete(owner: userB),
      throwsA(isA<PassportServiceException>()),
    );
    await expectLater(
      complete(completedAt: start.subtract(const Duration(seconds: 1))),
      throwsA(isA<PassportServiceException>()),
    );
    expect(notifications, 0);
  });
}
