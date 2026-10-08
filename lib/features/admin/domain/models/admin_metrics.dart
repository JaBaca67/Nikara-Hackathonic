import 'package:nikara_app/core/models/user_model.dart';

/// Conteos globales de la plataforma que muestra el panel de admin.
///
/// Se calcula en Dart sobre columnas sueltas (`is_verified`, `role`) y no con
/// un `count(*)` por métrica: son cuatro consultas de una columna contra el
/// tamaño actual de la base, y así un solo viaje por tabla alcanza para todos
/// los desgloses. Si la base crece a decenas de miles de filas, el reemplazo
/// natural es una vista materializada o un RPC de agregación — no más
/// `select` en el cliente.
class AdminMetrics {
  const AdminMetrics({
    required this.totalBusinesses,
    required this.verifiedBusinesses,
    required this.totalOrganizations,
    required this.verifiedOrganizations,
    required this.totalEcoActivities,
    required this.upcomingEcoActivities,
    required this.usersByRole,
  });

  const AdminMetrics.empty()
    : totalBusinesses = 0,
      verifiedBusinesses = 0,
      totalOrganizations = 0,
      verifiedOrganizations = 0,
      totalEcoActivities = 0,
      upcomingEcoActivities = 0,
      usersByRole = const {};

  final int totalBusinesses;
  final int verifiedBusinesses;
  final int totalOrganizations;
  final int verifiedOrganizations;
  final int totalEcoActivities;

  /// Jornadas cuyo `start_time` todavía no pasó.
  final int upcomingEcoActivities;

  final Map<UserRole, int> usersByRole;

  int get pendingBusinesses => totalBusinesses - verifiedBusinesses;

  int get pendingOrganizations => totalOrganizations - verifiedOrganizations;

  int get totalUsers =>
      usersByRole.values.fold<int>(0, (sum, count) => sum + count);

  int usersWithRole(UserRole role) => usersByRole[role] ?? 0;
}
