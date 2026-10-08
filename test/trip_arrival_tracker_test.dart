import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nikara_app/features/map/domain/trip_arrival_tracker.dart';

void main() {
  const destination = LatLng(11.9293, -85.9525);
  final start = DateTime.utc(2026, 10, 6, 18);
  final arrival = start.add(const Duration(minutes: 20));

  Position fix({
    double latitude = 11.9293,
    double longitude = -85.9525,
    double accuracy = 10,
    DateTime? timestamp,
    bool mocked = false,
  }) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? arrival,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    isMocked: mocked,
  );

  TripArrivalTracker tracker() =>
      TripArrivalTracker(destination: destination, startedAt: start);

  test('a distant fix cannot complete the trip; arrival seals only once', () {
    final trip = tracker();
    expect(trip.update(fix(latitude: 11.94), now: arrival), isNull);
    expect(trip.update(fix(latitude: 11.9296), now: arrival), arrival);
    expect(trip.update(fix(), now: arrival), isNull);
  });

  test(
    'invalid, stale, inaccurate and mocked fixes do not award a postcard',
    () {
      final trip = tracker();
      for (final invalid in [
        fix(timestamp: start.subtract(const Duration(seconds: 1))),
        fix(timestamp: arrival.subtract(const Duration(seconds: 31))),
        fix(timestamp: arrival.add(const Duration(seconds: 6))),
        fix(accuracy: 51),
        fix(accuracy: -1),
        fix(accuracy: double.nan),
        fix(latitude: double.nan),
        fix(longitude: 181),
        fix(mocked: true),
      ]) {
        expect(trip.update(invalid, now: arrival), isNull);
      }
      expect(trip.update(fix(), now: arrival), arrival);
    },
  );

  test('cancelled trips never receive an arrival seal', () {
    final trip = tracker()..cancel();
    expect(trip.update(fix(), now: arrival), isNull);
  });

  test('no seal outside the arrival radius or before starting', () {
    final trip = tracker();
    expect(trip.update(fix(latitude: 11.9301), now: arrival), isNull);
    expect(
      trip.update(fix(), now: start.subtract(const Duration(seconds: 1))),
      isNull,
    );
    expect(trip.update(fix(), now: arrival), arrival);
  });
}
