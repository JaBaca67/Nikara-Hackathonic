import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Datos de perfil sin columna en `profiles` de Supabase (username, categorías de interés, verificación de teléfono), guardados en SharedPreferences. `isPhoneVerified` siempre es `false` porque no hay proveedor de OTP configurado; "Saltar por ahora" es el camino esperado.
///
/// El avatar YA NO vive aquí: se guardaba bajo una sola clave global, no por
/// usuario, así que con el selector de cuentas el avatar del perfil anterior
/// se le pintaba al siguiente. Ahora es `profiles.avatar_url` (ver
/// [AuthService.updateAvatar] y supabase/sql/015_profile_avatars.sql). Las
/// claves que quedan sí son inofensivas al alternar: ninguna se muestra como
/// identidad de un usuario concreto.
class LocalProfileExtrasService {
  static const _keyLegacyAvatarPath = 'local_avatar_path';
  static const _keyUsername = 'local_username';
  static const _keyInterestCategories = 'local_interest_categories';
  static const _keyIsPhoneVerified = 'local_is_phone_verified';

  /// Borra el avatar local de versiones anteriores. Se llama una vez desde
  /// `main()`: si no, la foto del último usuario que la eligió se queda
  /// ocupando espacio para siempre sin que ninguna pantalla la lea ya.
  Future<void> clearLegacyAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLegacyAvatarPath);
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
