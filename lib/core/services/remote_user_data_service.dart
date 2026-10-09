import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Account content always comes from Supabase. Only its current UI snapshot
/// lives in memory. Failed writes must reach the caller, never fall back to disk.
class RemoteUserDataService {
  @visibleForTesting
  static bool realtimeEnabled = true;
  RemoteUserDataService({SupabaseClient? client}) : _providedClient = client;
  final SupabaseClient? _providedClient;
  SupabaseClient get client => _providedClient ?? Supabase.instance.client;

  String requireUser() {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Inicia sesión para guardar tus datos.');
    return id;
  }

  void requireSameUser(String id) {
    if (requireUser() != id) {
      throw StateError('La cuenta cambió durante la operación.');
    }
  }

  Future<void> Function() subscribe(
    List<String> tables,
    VoidCallback onChange,
  ) {
    if (!realtimeEnabled) return () async {};
    final channel = client.channel(
      'user-data:${tables.join('-')}:${DateTime.now().microsecondsSinceEpoch}',
    );
    for (final table in tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) onChange();
    });
    return () => client.removeChannel(channel);
  }
}
