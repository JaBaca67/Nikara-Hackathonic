import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the current, unauthenticated session is browsing as a
/// guest — set by "Explorar como invitado" on [LoginScreen], cleared the
/// moment that guest actually creates an account or signs in for real.
///
/// [isGuest] is a plain synchronous getter (mirrors
/// `AuthService.isLoggedIn`) so `app.dart` can decide LoginScreen vs.
/// MainLayout on the very first frame — that only works because [load] is
/// awaited once in `main()`, before `runApp()`, the same way
/// `Supabase.initialize()` already restores the real session up front.
class GuestSessionService {
  factory GuestSessionService() => instance;

  GuestSessionService._internal();

  static final GuestSessionService instance = GuestSessionService._internal();

  static const _keyIsGuest = 'local_is_guest';

  bool _isGuest = false;

  bool get isGuest => _isGuest;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool(_keyIsGuest) ?? false;
  }

  Future<void> enterGuestMode() async {
    _isGuest = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, true);
  }

  /// Called right after a guest actually creates an account or logs in for
  /// real, and on explicit sign-out — guest browsing shouldn't outlive
  /// either.
  Future<void> exitGuestMode() async {
    _isGuest = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsGuest);
  }
}
