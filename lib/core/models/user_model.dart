enum UserRole { client, owner }

/// A "Dev Mode" test identity — see [AuthService]. Distinct from
/// [UserSessionService]'s real, single, persisted device account: this
/// exists purely so a developer/QA can preview the client vs.
/// business-owner experience instantly, without registering a real
/// business or juggling multiple real logins.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.role,
    this.ownedBusinessIds = const [],
    this.favoriteBusinessIds = const [],
    this.points = 0,
  });

  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final UserRole role;
  final List<String> ownedBusinessIds;
  final List<String> favoriteBusinessIds;
  final int points;

  /// First-name + last-initial, e.g. "Sofía R." -> "SR" — used for the
  /// avatar fallback since [avatarUrl] is empty for both seed users.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    UserRole? role,
    List<String>? ownedBusinessIds,
    List<String>? favoriteBusinessIds,
    int? points,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      ownedBusinessIds: ownedBusinessIds ?? this.ownedBusinessIds,
      favoriteBusinessIds: favoriteBusinessIds ?? this.favoriteBusinessIds,
      points: points ?? this.points,
    );
  }
}
