import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';

/// Local persistence for [BusinessModel]s, backed by [SharedPreferences]
/// (the whole list round-trips as a single JSON string — there's no
/// backend, so this is the source of truth for every registered business).
/// Starts genuinely empty: no seeded/mock entry, so a fresh install shows
/// Home's empty state until the user registers a real business.
class BusinessStorageService {
  static const _key = 'businesses_json';

  /// Bumped on every write (add/update/delete/review). Screens listen to
  /// this the same way they listen to [FavoritesService]'s notifier —
  /// e.g. ProfileScreen's "Mis Negocios" and its points total (which
  /// depends on reviews written) stay live without needing a restart.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

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

  /// Upserts [business]: replaces the existing entry with a matching id,
  /// or appends it if there isn't one yet — the latter happens when a
  /// dev-fixture business (see `devBusinessFixtures`, never persisted) is
  /// edited and saved for the first time, promoting it into real storage.
  Future<void> updateBusiness(BusinessModel business) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBusinesses();
    final exists = current.any((b) => b.id == business.id);
    final updated = exists
        ? [for (final b in current) if (b.id == business.id) business else b]
        : [...current, business];
    await _write(prefs, updated);
  }

  Future<void> deleteBusiness(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBusinesses();
    await _write(prefs, current.where((b) => b.id != id).toList());
  }

  /// Appends [review] to the business's review list — [BusinessModel
  /// .averageRating] recomputes from that list on read, so nothing else
  /// needs to change for the rating to reflect it.
  Future<void> addReview(String businessId, ReviewModel review) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBusinesses();
    final updated = [
      for (final b in current)
        if (b.id == businessId)
          b.copyWith(reviews: [...b.reviews, review])
        else
          b,
    ];
    await _write(prefs, updated);
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<BusinessModel> businesses,
  ) async {
    final encoded = jsonEncode(businesses.map((b) => b.toJson()).toList());
    await prefs.setString(_key, encoded);
    revision.value++;
  }
}
