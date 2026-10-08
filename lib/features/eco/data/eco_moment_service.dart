import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:nikara_app/features/eco/domain/models/eco_moment_state.dart';

class EcoMomentException implements Exception {
  const EcoMomentException(this.message);
  final String message;
}

class EcoMomentService {
  factory EcoMomentService() => instance;
  EcoMomentService._internal();
  static final EcoMomentService instance = EcoMomentService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> Function() subscribeToChanges(
    String activityId,
    VoidCallback onChange,
  ) {
    final channel = _client.channel(
      'eco_moments:$activityId:${DateTime.now().microsecondsSinceEpoch}',
    );
    for (final table in ['reviews', 'eco_activities', 'eco_participants']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: table == 'reviews'
              ? 'target_id'
              : table == 'eco_activities'
              ? 'id'
              : 'activity_id',
          value: activityId,
        ),
        callback: (_) => onChange(),
      );
    }
    channel.subscribe();
    return () => _client.removeChannel(channel);
  }

  Future<EcoMomentState?> getState(String activityId) async {
    if (_client.auth.currentUser == null) return null;
    return _call('get_eco_moment_state', {'p_activity_id': activityId});
  }

  Future<EcoMomentState> savePolicy(
    String activityId, {
    required bool enabled,
    int? maxMessages,
    int? maxAccounts,
    int? maxPerAccount,
  }) => _call('set_eco_moment_policy', {
    'p_activity_id': activityId,
    'p_enabled': enabled,
    'p_max_messages': maxMessages,
    'p_max_accounts': maxAccounts,
    'p_max_per_account': maxPerAccount,
  });

  Future<EcoMomentState> _call(String name, Map<String, dynamic> params) async {
    try {
      final data = await _client.rpc(name, params: params);
      return EcoMomentState.fromJson(Map<String, dynamic>.from(data as Map));
    } on PostgrestException catch (e) {
      throw EcoMomentException(
        e.code == 'P0001'
            ? e.message
            : 'No se pudo consultar la configuración de Momentos. Intenta de nuevo.',
      );
    } catch (_) {
      throw const EcoMomentException(
        'Verifica tu conexión e intenta de nuevo.',
      );
    }
  }
}
