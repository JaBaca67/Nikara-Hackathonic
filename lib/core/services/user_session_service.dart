import 'package:shared_preferences/shared_preferences.dart';

/// Data snapshot of the single locally-registered user account.
class UserData {
  const UserData({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    this.location = '',
    this.avatarPath,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String email;

  /// e.g. "León, Nicaragua". Not collected by [RegisterScreen] yet, so this
  /// is empty for every account created today — genuinely absent, not a
  /// placeholder.
  final String location;

  /// On-device path (or, on web, a blob: URL) to the photo the user picked
  /// as their avatar via `image_picker`. Null until they actually set one —
  /// there is no default/mock photo.
  final String? avatarPath;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.trim().isNotEmpty ? firstName.trim()[0] : '';
    final last = lastName.trim().isNotEmpty ? lastName.trim()[0] : '';
    final combined = '$first$last'.toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }
}

/// Local session/account persistence backed by [SharedPreferences].
///
/// This app has no backend: registering "creates" the one account stored on
/// the device, and logging in simply checks the entered credentials against
/// it. `logout` only flips [isLoggedIn] off so the same account can log back
/// in without registering again.
class UserSessionService {
  static const _keyIsLoggedIn = 'session_is_logged_in';
  static const _keyFirstName = 'session_first_name';
  static const _keyLastName = 'session_last_name';
  static const _keyPhone = 'session_phone';
  static const _keyEmail = 'session_email';
  static const _keyPassword = 'session_password';
  static const _keyLocation = 'session_location';
  static const _keyAvatarPath = 'session_avatar_path';

  Future<void> registerUser({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirstName, firstName);
    await prefs.setString(_keyLastName, lastName);
    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, password);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  Future<bool> validateLogin(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_keyEmail);
    final storedPassword = prefs.getString(_keyPassword);
    if (storedEmail == null || storedPassword == null) return false;
    final matches =
        storedEmail.trim().toLowerCase() == email.trim().toLowerCase() &&
        storedPassword == password;
    if (matches) await prefs.setBool(_keyIsLoggedIn, true);
    return matches;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  Future<UserData?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    if (email == null) return null;
    return UserData(
      firstName: prefs.getString(_keyFirstName) ?? '',
      lastName: prefs.getString(_keyLastName) ?? '',
      phone: prefs.getString(_keyPhone) ?? '',
      email: email,
      location: prefs.getString(_keyLocation) ?? '',
      avatarPath: prefs.getString(_keyAvatarPath),
    );
  }

  Future<void> updateAvatar(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarPath, path);
  }

  Future<void> updateLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocation, location);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}
