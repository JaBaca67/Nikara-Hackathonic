import 'package:shared_preferences/shared_preferences.dart';

/// Indica si la sesión actual navega como invitado. Vive solo en memoria: el modo invitado no sobrevive a un arranque en frío, así que al reabrir la app el usuario vuelve a Login. [load] se espera una vez en `main()` antes de `runApp()` y solo limpia la marca que versiones anteriores dejaban en disco.
class GuestSessionService {
  factory GuestSessionService() => instance;

  GuestSessionService._internal();

  static final GuestSessionService instance = GuestSessionService._internal();

  /// Clave que versiones anteriores persistían; ya nada la escribe, solo se borra en [load].
  static const _legacyKeyIsGuest = 'local_is_guest';

  bool _isGuest = false;

  bool get isGuest => _isGuest;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKeyIsGuest);
    _isGuest = false;
  }

  Future<void> enterGuestMode() async {
    _isGuest = true;
  }

  /// Se llama al crear cuenta real, iniciar sesión, o cerrar sesión — la navegación como invitado no debe sobrevivir a ninguno de esos.
  Future<void> exitGuestMode() async {
    _isGuest = false;
  }
}
