import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Purely local, per-device profile data that has no column in Supabase's
/// `profiles` table — kept in SharedPreferences instead of lost. Same
/// honesty as before: null/empty/false until the user actually sets a
/// value, never a default/mock placeholder.
///
/// Covers: avatar photo, username, interest categories (from the
/// registration wizard's Paso 4) and `isPhoneVerified` (Paso 3's OTP step
/// — there's no SMS/email OTP provider configured in Supabase, so this is
/// always `false` unless a real verification flow gets wired up later;
/// "Saltar por ahora" is the expected, fully-supported path).
///
/// Replaces the old `UserSessionService`, which used to also own local
/// mock login/registration — that's now real, via `AuthService`.
class LocalProfileExtrasService {
  static const _keyAvatarPath = 'local_avatar_path';
  static const _keyUsername = 'local_username';
  static const _keyInterestCategories = 'local_interest_categories';
  static const _keyIsPhoneVerified = 'local_is_phone_verified';

  Future<String?> getAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAvatarPath);
  }

  Future<void> updateAvatar(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarPath, path);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  Future<void> updateUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  Future<List<String>> getInterestCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyInterestCategories);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> updateInterestCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInterestCategories, jsonEncode(categories));
  }

  Future<bool> getIsPhoneVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPhoneVerified) ?? false;
  }

  Future<void> updateIsPhoneVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPhoneVerified, verified);
  }
}
