import 'package:shared_preferences/shared_preferences.dart';

/// Indica si la sesión actual navega como invitado; [isGuest] es síncrono porque [load] se espera una vez en `main()` antes de `runApp()`.
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

  /// Se llama al crear cuenta real, iniciar sesión, o cerrar sesión — la navegación como invitado no debe sobrevivir a ninguno de esos.
  Future<void> exitGuestMode() async {
    _isGuest = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsGuest);
  }
}
