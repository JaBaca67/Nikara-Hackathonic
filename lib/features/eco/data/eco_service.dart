import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';

class EcoServiceException implements Exception {
  const EcoServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persists [EcoActivityModel]s to Supabase's `eco_activities` table and
/// join/leave actions to `eco_participants` (see
/// supabase/sql/009_eco_activities.sql) — the ECO tab's single source of
/// truth, same singleton-service pattern as [BusinessStorageService].
class EcoService {
  factory EcoService() => EcoService.instance;

  EcoService._internal();

  static final EcoService instance = EcoService._internal();

  /// Bumped on every write this device makes (join/leave/create) — screens
  /// listen to this the same way they listen to `BusinessStorageService
  /// .revision` so e.g. EcoMainScreen refreshes instantly after
  /// [createActivity] without a manual pull-to-refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  /// Every activity that hasn't already ended (`start_time` in the past
  /// activities are excluded here — [getPastActivities] is the separate
  /// call for those), newest-start-first isn't the ordering EcoMainScreen
  /// wants (soonest-first reads as "what's coming up"), so this orders by
  /// `start_time` ascending.
  Future<List<EcoActivityModel>> getUpcomingActivities() async {
    return _select(pastOnly: false);
  }

  /// Activities whose `start_time` has already passed — Estado 3
  /// ("Completada"), fetched separately from [getUpcomingActivities] so
  /// the main feed never has to filter/sort a mixed list client-side.
  Future<List<EcoActivityModel>> getPastActivities() async {
    return _select(pastOnly: true);
  }

  Future<List<EcoActivityModel>> _select({required bool pastOnly}) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      // eco_participants(user_id, joined_at) is embedded via Postgrest's
      // nested-select syntax — one round trip gets every activity's full
      // participant list, which EcoActivityModel.fromRow reduces into
      // participantCount/isJoinedByCurrentUser instead of a query per
      // activity (or per activity per user).
      var query = _client
          .from('eco_activities')
          .select('*, eco_participants(user_id, joined_at)');
      query = pastOnly
          ? query.lt('start_time', nowIso)
          : query.gte('start_time', nowIso);
      final rows = await query.order('start_time', ascending: !pastOnly);
      final currentUserId = AuthService().currentAuthUser?.id;
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) =>
                EcoActivityModel.fromRow(row, currentUserId: currentUserId),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudieron cargar las actividades: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<EcoActivityModel?> getActivityById(String id) async {
    try {
      final row = await _client
          .from('eco_activities')
          .select('*, eco_participants(user_id, joined_at)')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return EcoActivityModel.fromRow(
        row,
        currentUserId: AuthService().currentAuthUser?.id,
      );
    } on PostgrestException catch (e) {
      throw EcoServiceException('No se pudo cargar la actividad: ${e.message}');
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Every participant's `user_id`/`joined_at` for the detail screen's
  /// "Participantes" tab — `profiles` isn't embeddable here (no direct FK
  /// between `eco_participants` and `public.profiles`, both instead point
  /// at `auth.users`), so display names are resolved separately, per id,
  /// via `AuthService.getProfileById`.
  Future<List<({String userId, DateTime joinedAt})>> getParticipants(
    String activityId,
  ) async {
    try {
      final rows = await _client
          .from('eco_participants')
          .select('user_id, joined_at')
          .eq('activity_id', activityId)
          .order('joined_at');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => (
              userId: row['user_id'] as String,
              joinedAt: DateTime.parse(row['joined_at'] as String),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudieron cargar los participantes: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// "Unirme" — the caller is expected to have already gated this behind
  /// [GuestGuard.allow] (a guest has no `auth.users` id to insert).
  Future<void> joinActivity(String activityId) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para unirte a una actividad.',
      );
    }
    try {
      await _client.from('eco_participants').insert({
        'activity_id': activityId,
        'user_id': userId,
      });
      revision.value++;
    } on PostgrestException catch (e) {
      // Unique-violation on the (activity_id, user_id) primary key means
      // the user is already in — not a real failure from their point of
      // view, so it's worth a friendlier message than the raw Postgres one.
      if (e.code == '23505') {
        throw const EcoServiceException(
          'Ya estás participando en esta actividad.',
        );
      }
      throw EcoServiceException(
        'No se pudo completar la inscripción: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// "Abandonar actividad".
  Future<void> leaveActivity(String activityId) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para gestionar tus actividades.',
      );
    }
    try {
      await _client
          .from('eco_participants')
          .delete()
          .eq('activity_id', activityId)
          .eq('user_id', userId);
      revision.value++;
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudo abandonar la actividad: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// [CreateEcoActivityScreen]'s save action — the organizer is always the
  /// currently signed-in user's real name (from their `profiles` row via
  /// [AuthService.getCurrentProfile]), never a client-supplied "verified"
  /// claim: `organizer_verified` is intentionally left at its column
  /// default (`false`) here, same reasoning as `BusinessModel.isVerified`
  /// — nothing in the client ever sets that itself.
  Future<void> createActivity({
    required String title,
    required String description,
    required String category,
    required String location,
    double? latitude,
    double? longitude,
    required DateTime startTime,
    int? maxCapacity,
    List<String> requirements = const [],
  }) async {
    final user = AuthService().currentAuthUser;
    if (user == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para registrar una actividad.',
      );
    }
    try {
      final profile = await AuthService().getCurrentProfile();
      await _client.from('eco_activities').insert({
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'start_time': startTime.toUtc().toIso8601String(),
        'max_capacity': maxCapacity,
        'organizer_id': user.id,
        'organizer_name': profile?.fullName,
        'requirements': requirements,
      });
      revision.value++;
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudo guardar la actividad: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Subscribes to Postgres INSERT/UPDATE/DELETE on both ECO tables and
  /// calls [onChange] for each one — how EcoMainScreen picks up an
  /// activity someone else created, or a join/leave from another device,
  /// without the user having to reopen the tab. [revision] covers changes
  /// made by this device; this covers the rest. Silent by design if
  /// Realtime isn't enabled for either table (see the migration file):
  /// the channel subscribes fine, no events ever arrive, and the app keeps
  /// working off its normal fetches.
  Future<void> Function() subscribeToChanges(VoidCallback onChange) {
    final channel = _client
        .channel('public:eco_activities_and_participants')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eco_activities',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eco_participants',
          callback: (_) => onChange(),
        )
        .subscribe();
    return () => _client.removeChannel(channel);
  }
}
