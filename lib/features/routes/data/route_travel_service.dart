import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/route_model.dart';
import '../domain/models/route_stop_model.dart';

enum StopVisitStatus { visited, skipped }

class RouteTravelSession {
  RouteTravelSession({
    required this.route,
    required this.accountId,
    this.progress = const {},
  });
  final RouteModel route;
  final String accountId;
  final Map<String, StopVisitStatus> progress;
  bool isPending(RouteStopModel stop) => !progress.containsKey(stop.visitKey);
  int get visitedCount => route.stops
      .where((s) => progress[s.visitKey] == StopVisitStatus.visited)
      .length;
  bool get isFinished =>
      route.stops.isNotEmpty && route.stops.every((s) => !isPending(s));
  RouteStopModel? nextForDay(int day) =>
      route.stopsForDay(day).where(isPending).firstOrNull;
}

/// Personal progress on this device, separate from the shared itinerary.
/// Keys include the account and stable source identity (editing recreates row IDs).
class RouteTravelService {
  factory RouteTravelService() => instance;
  RouteTravelService._internal();
  @visibleForTesting
  RouteTravelService.forTesting();
  static final instance = RouteTravelService._internal();
  final active = ValueNotifier<RouteTravelSession?>(null);
  Future<void> _writes = Future.value();

  String _key(String accountId, String routeId) =>
      'route_travel_v1:$accountId:$routeId';

  Future<void> open(RouteModel route, {required String accountId}) async {
    await _writes;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(accountId, route.id));
    final progress = <String, StopVisitStatus>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final stop in route.stops) {
          final value = decoded[stop.visitKey];
          if (value == 'visited') {
            progress[stop.visitKey] = StopVisitStatus.visited;
          }
          if (value == 'skipped') {
            progress[stop.visitKey] = StopVisitStatus.skipped;
          }
        }
      } on FormatException {
        // An invalid local cache does not prevent starting a new journey.
      } on TypeError {
        // Older/invalid cache shape.
      }
    }
    active.value = RouteTravelSession(
      route: route,
      accountId: accountId,
      progress: Map.unmodifiable(progress),
    );
  }

  /// Removes the map's active route without deleting the visit checklist.
  Future<void> deactivate({
    required String accountId,
    required String routeId,
  }) async {
    await _writes;
    final session = active.value;
    if (session?.route.id == routeId && session?.accountId == accountId) {
      active.value = null;
    }
  }

  Future<void> setStatus({
    required String accountId,
    required String routeId,
    required String visitKey,
    StopVisitStatus? status,
  }) {
    final write = _writes.then((_) async {
      final session = active.value;
      if (session == null ||
          session.route.id != routeId ||
          session.accountId != accountId ||
          !session.route.stops.any((s) => s.visitKey == visitKey)) {
        throw StateError('Esta sesión de ruta ya no está activa.');
      }
      final progress = {...session.progress};
      if (status == null) {
        progress.remove(visitKey);
      } else {
        progress[visitKey] = status;
      }
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _key(accountId, routeId),
        jsonEncode(progress.map((key, value) => MapEntry(key, value.name))),
      );
      if (!saved) throw StateError('No se pudo guardar el progreso.');
      if (active.value == session) {
        active.value = RouteTravelSession(
          route: session.route,
          accountId: accountId,
          progress: Map.unmodifiable(progress),
        );
      }
    });
    // A failed write must not poison the queue for retries.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
