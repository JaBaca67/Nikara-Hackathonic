/// Mirrors Supabase's `public.profiles.role` enum (`user_role`) exactly —
/// the member names below (`.name`) are sent/read as-is against Postgres.
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

/// A row from Supabase's `profiles` table — `id` is the same uuid as
/// `auth.users.id`. This is the app's one real, backend-verified user
/// identity (see [AuthService]); there is no local/mock stand-in for it.
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone = '',
    this.points = 0,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String phone;

  /// `profiles.points` — not yet written to by any flow in this app (no
  /// gamification action currently syncs to Supabase), so this reads back
  /// whatever value the row already has, genuinely 0 for a fresh signup.
  final int points;

  /// Just the first token of [fullName], e.g. "Ixchel Galo Martínez" ->
  /// "Ixchel" — used for the Home header's "Buen día, {firstName}" greeting.
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// First-name + last-initial, e.g. "Ixchel Galo" -> "IG" — used for the
  /// avatar fallback since `profiles` has no avatar column.
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
    );
  }
}
