/// Replica el enum `user_role` de Supabase (`public.profiles.role`); los
/// nombres se envían/leen tal cual contra Postgres.
///
/// `auditor` existió acá hasta el 2026-08-27: se definió al inicio del
/// proyecto pero nunca se le dio un rol real distinto de `admin` (nadie llegó
/// a registrarse con él — confirmado en `profiles` antes de sacarlo). El tipo
/// `user_role` de Postgres puede seguir teniendo el valor `'auditor'` sin que
/// esto rompa nada: si alguna fila vieja lo tuviera, [_roleFromString] lo
/// degrada a `turista` por el mismo `default` que ya cubre cualquier valor
/// desconocido.
enum UserRole { turista, emprendedor, admin }

UserRole _roleFromString(String? raw) {
  switch (raw) {
    case 'emprendedor':
      return UserRole.emprendedor;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.turista;
  }
}

/// Fila de la tabla `profiles`; `id` es el mismo uuid que `auth.users.id`. Única identidad de usuario real (ver [AuthService]), sin equivalente local/mock.
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone = '',
    this.points = 0,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String phone;

  /// `profiles.avatar_url` — URL pública del bucket `avatars` de Storage (ver
  /// supabase/sql/015_profile_avatars.sql). Es la única fuente de verdad del
  /// avatar: guardarlo en `SharedPreferences` hacía que al alternar de cuenta
  /// el avatar del usuario anterior se le pintara al siguiente, y que nadie
  /// más pudiera verlo. Nula = se cae a [initials].
  final String? avatarUrl;

  /// `profiles.points` — ningún flujo de la app escribe aquí todavía (sin sync de gamificación a Supabase); 0 en una cuenta nueva.
  final int points;

  /// Primer token de [fullName], p. ej. "Ixchel Galo Martínez" -> "Ixchel", para el saludo "Buen día, {firstName}" del Home.
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Inicial de nombre + apellido, p. ej. "Ixchel Galo" -> "IG"; fallback cuando [avatarUrl] es nula.
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  factory UserModel.fromRow(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'] as String,
      fullName: row['full_name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      role: _roleFromString(row['role'] as String?),
      phone: row['phone'] as String? ?? '',
      points: (row['points'] as num?)?.toInt() ?? 0,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}

/// Capacidades atómicas que la app sabe conceder o negar.
///
/// Existe como enum y no como un `bool` por pantalla para que la tabla
/// rol -> permisos de [UserRolePermissions] sea una sola declaración legible:
/// al agregar un rol o mover una capacidad de un rol a otro se edita un único
/// lugar, en vez de perseguir condicionales sueltas por la UI.
enum Permission {
  // --- Consumo de contenido (base de todos los roles) ---
  /// Explorar negocios, jornadas ECO, rutas públicas y mapa.
  browseContent,

  /// Guardar y quitar favoritos.
  saveFavorites,

  /// Inscribirse y darse de baja de una jornada ECO.
  joinEcoActivity,

  // --- Contenido propio (emprendedor) ---
  /// Crear, editar y eliminar los negocios **propios**.
  manageOwnBusinesses,

  /// Crear, editar y eliminar las rutas **propias**.
  manageOwnRoutes,

  /// Crear, editar y eliminar las jornadas/organizaciones ECO **propias**.
  manageOwnEcoActivities,

  // --- Moderación (auditor) ---
  /// Abrir el panel y ver la cola de registros pendientes de revisión.
  reviewSubmissions,

  /// Escribir `businesses.is_verified` (verificar / quitar verificación).
  verifyBusiness,

  /// Escribir `organizations.is_verified`.
  verifyOrganization,

  // --- Administración (admin) ---
  /// Ver el panel de métricas globales de la plataforma.
  viewGlobalMetrics,

  /// Ver el listado de perfiles y su rol.
  manageUsers,
}

/// Permisos diferenciados por rol — la única fuente de verdad de "quién puede
/// qué" en la app.
///
/// Vive como extensión pura sobre el enum (sin I/O, sin Supabase) a propósito:
/// la tabla se puede leer y testear de un vistazo, y queda pegada al enum que
/// describe, así ninguno de los dos puede derivar del otro. La parte que sí
/// necesita sesión y caché — "qué rol tiene el usuario de ahora mismo" — vive
/// aparte en `PermissionService`.
///
extension UserRolePermissions on UserRole {
  static const _turista = <Permission>{
    Permission.browseContent,
    Permission.saveFavorites,
    Permission.joinEcoActivity,
  };

  static const _emprendedor = <Permission>{
    ..._turista,
    Permission.manageOwnBusinesses,
    Permission.manageOwnRoutes,
    Permission.manageOwnEcoActivities,
  };

  static const _admin = <Permission>{
    Permission.browseContent,
    Permission.saveFavorites,
    Permission.joinEcoActivity,
    Permission.manageOwnBusinesses,
    Permission.manageOwnRoutes,
    Permission.manageOwnEcoActivities,
    Permission.reviewSubmissions,
    Permission.verifyBusiness,
    Permission.verifyOrganization,
    Permission.viewGlobalMetrics,
    Permission.manageUsers,
  };

  Set<Permission> get permissions => switch (this) {
    UserRole.turista => _turista,
    UserRole.emprendedor => _emprendedor,
    UserRole.admin => _admin,
  };

  bool can(Permission permission) => permissions.contains(permission);

  /// Puerta única de entrada al panel: si esto es falso, la fila de Ajustes ni
  /// siquiera se dibuja (un turista no debe enterarse de que el panel existe).
  bool get canAccessAdminPanel => can(Permission.reviewSubmissions);

  /// Etiqueta visible del rol, en español.
  String get label => switch (this) {
    UserRole.turista => 'Turista',
    UserRole.emprendedor => 'Emprendedor',
    UserRole.admin => 'Equipo Níkara',
  };

  /// Descripción corta de qué habilita el rol; se muestra en el listado de
  /// usuarios del panel.
  String get permissionsSummary => switch (this) {
    UserRole.turista => 'Explora, guarda favoritos y se une a jornadas ECO',
    UserRole.emprendedor => 'Publica y gestiona sus negocios, rutas y jornadas',
    UserRole.admin => 'Revisión, métricas globales y gestión de usuarios',
  };
}
