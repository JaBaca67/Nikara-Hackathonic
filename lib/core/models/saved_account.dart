import 'package:nikara_app/core/models/user_model.dart';

/// Una sesión de Supabase guardada localmente para poder volver a ella sin
/// reescribir la contraseña (ver `AccountSwitcherService`).
///
/// Solo persiste el `refresh_token`, nunca el `access_token`: el access token
/// caduca en una hora y de todas formas hay que pedir uno nuevo al alternar,
/// así que guardarlo sería exponer un secreto extra sin ganar nada.
class SavedAccount {
  const SavedAccount({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.refreshToken,
    required this.savedAt,
    this.avatarUrl,
  });

  /// Mismo uuid que `auth.users.id` / `profiles.id`.
  final String userId;
  final String email;
  final String fullName;
  final UserRole role;

  /// El token con el que `GoTrueClient.setSession` reconstruye la sesión.
  final String refreshToken;

  /// Última vez que se refrescó la entrada; ordena la lista (lo más reciente primero).
  final DateTime savedAt;

  final String? avatarUrl;

  /// Nombre visible con fallback al correo: una cuenta creada por OAuth puede
  /// no tener `full_name` todavía.
  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final localPart = email.split('@').first;
    return localPart.isEmpty ? 'Cuenta Níkara' : localPart;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  /// Etiqueta del rol tal como la muestra el selector de cuentas.
  String get roleLabel => switch (role) {
    UserRole.turista => 'Turista',
    UserRole.emprendedor => 'Emprendedor',
    UserRole.admin => 'Equipo Níkara',
    UserRole.auditor => 'Auditor',
  };

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'full_name': fullName,
    'role': role.name,
    'refresh_token': refreshToken,
    'saved_at': savedAt.toIso8601String(),
    'avatar_url': avatarUrl,
  };

  /// Devuelve null si el JSON está incompleto (versión anterior del formato o
  /// escritura a medias): una entrada corrupta se descarta en vez de romper
  /// todo el selector de cuentas.
  static SavedAccount? fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    if (userId == null || refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    return SavedAccount(
      userId: userId,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.turista,
      ),
      refreshToken: refreshToken,
      savedAt:
          DateTime.tryParse(json['saved_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
