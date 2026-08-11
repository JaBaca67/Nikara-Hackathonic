import 'package:shared_preferences/shared_preferences.dart';

/// Purely local, per-device profile data that has no column in Supabase's
/// `profiles` table (there's no `avatar_url` there) — kept in
/// SharedPreferences instead of lost. Same honesty as before: null until
/// the user actually picks a photo, never a default/mock image.
///
/// Replaces the old `UserSessionService`, which used to also own local
/// mock login/registration — that's now real, via [AuthService].
class LocalProfileExtrasService {
  static const _keyAvatarPath = 'local_avatar_path';

  Future<String?> getAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAvatarPath);
  }

  Future<void> updateAvatar(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarPath, path);
  }
}