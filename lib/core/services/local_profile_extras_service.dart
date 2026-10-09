import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Retires obsolete global keys and transfers legacy account-owned trips.
/// Never saves new account content to device preferences.
class LocalProfileExtrasService {
  Future<void> clearLegacyAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    const exact = {
      'local_avatar_path',
      'local_username',
      'local_interest_categories',
      'local_is_phone_verified',
      'favorite_destination_ids',
    };
    for (final key in prefs.getKeys().toList()) {
      if (exact.contains(key) ||
          key.startsWith('favorite_ids_') ||
          key.startsWith('favorite_cache_') ||
          key.startsWith('notifications_demo_v1_')) {
        await prefs.remove(key);
      }
    }
  }

  /// Existing account-owned data is removed only after Supabase confirms it.
  /// Global conversations have no trustworthy owner and are never imported.
  Future<void> migrateAccountData({SupabaseClient? client}) async {
    final remote = client ?? Supabase.instance.client;
    final userId = remote.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    void requireOwner() {
      if (remote.auth.currentUser?.id != userId) {
        throw StateError('La cuenta cambió durante la migración.');
      }
    }

    final passportKey = 'completed_business_trips_v1_$userId';
    final passport = prefs.getString(passportKey);
    if (passport != null) {
      final trips = jsonDecode(passport) as List<dynamic>;
      for (final item in trips) {
        requireOwner();
        final trip = item as Map<String, dynamic>;
        final postcard = trip['postcard'] as Map<String, dynamic>;
        await remote.rpc(
          'record_passport_trip',
          params: {
            'p_trip_id': trip['id'],
            'p_business_id': postcard['id'],
            'p_started_at': trip['started_at'],
            'p_completed_at': postcard['sealed_at'],
          },
        );
      }
      requireOwner();
      await prefs.remove(passportKey);
    }
    final prefix = 'route_travel_v1:$userId:';
    for (final key
        in prefs.getKeys().where((key) => key.startsWith(prefix)).toList()) {
      final routeId = key.substring(prefix.length);
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final progress = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in progress.entries) {
        requireOwner();
        await remote
            .from('route_visit_progress')
            .upsert({
              'user_id': userId,
              'route_id': routeId,
              'visit_key': entry.key,
              'status': entry.value,
            }, onConflict: 'user_id,route_id,visit_key')
            .select('visit_key')
            .single();
      }
      requireOwner();
      await prefs.remove(key);
    }
  }
}
