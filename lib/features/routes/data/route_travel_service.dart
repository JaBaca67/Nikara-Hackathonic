import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/services/remote_user_data_service.dart';
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

/// Private progress stored in Supabase, separate from the shared itinerary.
/// Keys include the account and stable source identity (editing recreates row IDs).
class RouteTravelService {
  factory RouteTravelService() => instance;
  RouteTravelService._internal()
    : _remote = RemoteUserDataService(),
      currentUserId = null;
  @visibleForTesting
  RouteTravelService.forTesting({SupabaseClient? client, this.currentUserId})
    : _remote = RemoteUserDataService(client: client);
  final RemoteUserDataService _remote;
  final String? Function()? currentUserId;
  void _requireAccount(String id) {
    final actual = currentUserId == null
        ? _remote.client.auth.currentUser?.id
        : currentUserId!();
    if (actual == null || actual != id) {
      throw StateError('Inicia sesión con la cuenta del recorrido.');
    }
  }

  static final instance = RouteTravelService._internal();
  final active = ValueNotifier<RouteTravelSession?>(null);
  Future<void> _writes = Future.value();

  Future<void> refresh() async {
    final session = active.value;
    if (session != null) {
      await open(session.route, accountId: session.accountId);
    }
  }

  void invalidate() => active.value = null;

  Future<void> open(RouteModel route, {required String accountId}) async {
    await _writes;
    _requireAccount(accountId);
    final rows = await _remote.client
        .from('route_visit_progress')
        .select('visit_key,status')
        .eq('user_id', accountId)
        .eq('route_id', route.id);
    _requireAccount(accountId);
    final valid = route.stops.map((s) => s.visitKey).toSet();
    final progress = <String, StopVisitStatus>{};
    for (final row in rows) {
      final key = row['visit_key'] as String;
      if (valid.contains(key)) {
        progress[key] = row['status'] == 'visited'
            ? StopVisitStatus.visited
            : StopVisitStatus.skipped;
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
      _requireAccount(accountId);
      if (status == null) {
        await _remote.client
            .from('route_visit_progress')
            .delete()
            .eq('user_id', accountId)
            .eq('route_id', routeId)
            .eq('visit_key', visitKey);
      } else {
        await _remote.client
            .from('route_visit_progress')
            .upsert({
              'user_id': accountId,
              'route_id': routeId,
              'visit_key': visitKey,
              'status': status.name,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'user_id,route_id,visit_key')
            .select('visit_key')
            .single();
      }
      _requireAccount(accountId);
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
