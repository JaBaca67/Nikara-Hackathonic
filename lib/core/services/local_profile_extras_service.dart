import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Datos de perfil sin columna en `profiles` de Supabase (avatar, username, categorías de interés, verificación de teléfono), guardados en SharedPreferences. `isPhoneVerified` siempre es `false` porque no hay proveedor de OTP configurado; "Saltar por ahora" es el camino esperado.
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
