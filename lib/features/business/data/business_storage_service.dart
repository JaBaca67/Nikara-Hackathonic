import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';

/// Local persistence for [BusinessModel]s, backed by [SharedPreferences]
/// (the whole list round-trips as a single JSON string — there's no
/// backend, so this is the source of truth for every registered business).
/// Starts genuinely empty: no seeded/mock entry, so a fresh install shows
/// Home's empty state until the user registers a real business.
class BusinessStorageService {
  static const _key = 'businesses_json';

  Future<List<BusinessModel>> getBusinesses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => BusinessModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addBusiness(BusinessModel business) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBusinesses();
    await _write(prefs, [...current, business]);
  }

  Future<void> updateBusiness(BusinessModel business) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBusinesses();
    final updated = [
      for (final b in current) if (b.id == business.id) business else b,
    ];
    await _write(prefs, updated);
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<BusinessModel> businesses,
  ) async {
    final encoded = jsonEncode(businesses.map((b) => b.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
