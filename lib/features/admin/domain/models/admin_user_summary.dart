import 'package:nikara_app/core/models/user_model.dart';

/// Fila de `profiles` tal como la lista el panel: identidad mínima + rol.
///
/// No incluye `phone` ni `points`: el listado existe para auditar **roles**,
/// no para exponer datos de contacto de todos los usuarios a quien abra el
/// panel.
class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
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

  factory AdminUserSummary.fromRow(Map<String, dynamic> row) {
    return AdminUserSummary(
      id: row['id'] as String,
      fullName: row['full_name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == row['role'],
        orElse: () => UserRole.turista,
      ),
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}
