/// Replica el enum `user_role` de Supabase (`public.profiles.role`); los nombres se envían/leen tal cual contra Postgres.
enum UserRole { turista, emprendedor, admin, auditor }

UserRole _roleFromString(String? raw) {
  switch (raw) {
    case 'emprendedor':
      return UserRole.emprendedor;
    case 'admin':
      return UserRole.admin;
    case 'auditor':
      return UserRole.auditor;
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
