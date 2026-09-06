import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';

/// Se lanza cuando el rol del usuario activo no alcanza para la acción pedida.
/// [message] ya viene en español, listo para un SnackBar o un diálogo.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resuelve "qué puede hacer el usuario de ahora mismo".
///
/// La tabla de permisos en sí no vive acá sino en `UserRolePermissions`
/// (extensión pura sobre [UserRole], en `user_model.dart`): esa parte no
/// necesita red y se testea sola. Este servicio aporta lo que sí necesita
/// sesión — leer el rol del perfil activo, cachearlo para que la UI pueda
/// preguntar de forma síncrona en un `build`, e invalidarlo al cambiar de
/// cuenta.
///
/// La caché se llavea por `userId` justamente por el selector de cuentas: sin
/// eso, alternar de un admin a un turista dejaría al turista con el panel
/// visible hasta reiniciar la app.
class PermissionService {
  factory PermissionService() => instance;

  PermissionService._internal();

  static final PermissionService instance = PermissionService._internal();

  AuthService get _auth => AuthService();

  UserRole? _cachedRole;
  String? _cachedUserId;

  /// Rol conocido del usuario activo, sin tocar la red.
  ///
  /// Devuelve `turista` (el rol de menor privilegio) mientras no se haya
  /// llamado a [load], o si la sesión cambió desde la última carga. Es un
  /// default deliberado: ante la duda, la UI oculta en vez de mostrar.
  UserRole get currentRole {
    final userId = _auth.currentAuthUser?.id;
    if (userId == null || userId != _cachedUserId) return UserRole.turista;
    return _cachedRole ?? UserRole.turista;
  }

  /// `true` solo si ya se resolvió el rol de la sesión activa. Sirve para que
  /// una pantalla no dibuje "no tenés permiso" mientras todavía está cargando.
  bool get isResolved =>
      _cachedUserId != null && _cachedUserId == _auth.currentAuthUser?.id;

  /// Lee el rol del perfil activo y lo cachea.
  ///
  /// Un fallo de red no se traga ni se propaga como excepción cruda: se
  /// devuelve `turista` y la caché queda sin resolver, así el siguiente
  /// intento vuelve a consultar en vez de quedarse con un permiso inventado.
  Future<UserRole> load({bool force = false}) async {
    final userId = _auth.currentAuthUser?.id;
    if (userId == null) {
      invalidate();
      return UserRole.turista;
    }
    if (!force && _cachedUserId == userId && _cachedRole != null) {
      return _cachedRole!;
    }
    try {
      final profile = await _auth.getProfileById(userId);
      if (profile == null) return UserRole.turista;
      _cachedUserId = userId;
      _cachedRole = profile.role;
      return profile.role;
    } on AuthServiceException {
      invalidate();
      return UserRole.turista;
    }
  }

  bool can(Permission permission) => currentRole.can(permission);

  /// Versión asíncrona de [can]: resuelve el rol si hace falta antes de
  /// contestar. La usan los servicios de datos, que no pueden asumir que
  /// alguna pantalla ya llamó a [load].
  Future<bool> canAsync(Permission permission) async {
    final role = await load();
    return role.can(permission);
  }

  /// Puerta obligatoria antes de cualquier mutación privilegiada.
  ///
  /// Chequear acá **no es seguridad real** mientras RLS siga deshabilitada
  /// (ver CLAUDE.md > "Supabase & Security Guidelines"): cualquiera puede
  /// llamar a la REST API sin pasar por la app. Es higiene de código y la
  /// preparación para que `019_review_status.sql` mueva esta misma validación
  /// al servidor, donde sí es vinculante.
  Future<void> require(Permission permission, {required String action}) async {
    if (_auth.currentAuthUser == null) {
      throw PermissionDeniedException('Necesitas iniciar sesión para $action.');
    }
    if (await canAsync(permission)) return;
    throw PermissionDeniedException(
      'Tu cuenta (${currentRole.label}) no tiene permiso para $action.',
    );
  }

  /// Olvida el rol cacheado. Llamar al cerrar sesión o al alternar de cuenta.
  void invalidate() {
    _cachedRole = null;
    _cachedUserId = null;
  }
}
