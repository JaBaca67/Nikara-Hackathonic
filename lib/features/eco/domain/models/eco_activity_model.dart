/// Estados 1/2/3 de "fases-pantalla-eco"; derivado siempre desde [EcoActivityModel.status], nunca almacenado.
enum EcoActivityStatus {
  /// Estado 1 — próxima, sin unirse. "Unirme" (dorado).
  available,

  /// Estado 2 — próxima, ya unido. "Abandonar actividad" + indicador "Participando".
  joined,

  /// Estado 3 — ya pasó. Badge inactivo, se muestra el conteo final de participantes.
  completed,
}

/// `eco_activities.category` sigue siendo texto libre (igual que `businesses.category`); este set es solo el curado que ofrece la UI, para no requerir migración por cada categoría nueva.
const List<String> kEcoCategories = ['Reforestación', 'Fauna', 'Limpieza'];

/// Fila de `eco_activities` más [participantCount]/[isJoinedByCurrentUser], calculados por [EcoService] desde el embed `eco_participants` en vez de un round-trip aparte.
class EcoActivityModel {
  const EcoActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    this.latitude,
    this.longitude,
    required this.startTime,
    this.maxCapacity,
    this.organizerId,
    this.organizerName,
    this.organizerVerified = false,
    this.organizationId,
    this.organizationName,
    this.organizationHandle,
    this.organizationLogoUrl,
    this.organizationVerified = false,
    this.requirements = const [],
    required this.createdAt,
    this.participantCount = 0,
    this.isJoinedByCurrentUser = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;

  /// Etiqueta corta ("Cerro Apante, Managua"), no una dirección completa — mismo rol que `BusinessModel.city`.
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime startTime;

  /// Null significa "sin cupo límite" — [spotsAvailable]/[isFull] lo leen como siempre-abierto.
  final int? maxCapacity;

  final String? organizerId;
  final String? organizerName;
  final bool organizerVerified;

  /// Nulo si la jornada la publicó una persona a título personal; los cuatro campos siguientes vienen del embed `organizations(...)`, no de columnas propias.
  final String? organizationId;
  final String? organizationName;
  final String? organizationHandle;
  final String? organizationLogoUrl;
  final bool organizationVerified;

  bool get isFromOrganization =>
      organizationId != null && organizationId!.isNotEmpty;

  final List<String> requirements;
  final DateTime createdAt;

  final int participantCount;
  final bool isJoinedByCurrentUser;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isPast => startTime.isBefore(DateTime.now());

  EcoActivityStatus get status {
    if (isPast) return EcoActivityStatus.completed;
    return isJoinedByCurrentUser
        ? EcoActivityStatus.joined
        : EcoActivityStatus.available;
  }

  /// "Empieza pronto": próxima y dentro de una semana.
  bool get startsSoon =>
      !isPast && startTime.difference(DateTime.now()).inDays < 7;

  int? get spotsAvailable {
    final cap = maxCapacity;
    if (cap == null) return null;
    final remaining = cap - participantCount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isFull => spotsAvailable == 0;

  /// Nombre de la fundación si publicó en su nombre, si no el de quien la creó, y un genérico como último recurso.
  String get organizerDisplayName {
    final organization = organizationName;
    if (isFromOrganization &&
        organization != null &&
        organization.trim().isNotEmpty) {
      return organization;
    }
    return (organizerName == null || organizerName!.trim().isEmpty)
        ? 'Organizador'
        : organizerName!;
  }

  /// Badge "VERIFICADO": de la fundación si es suya, si no el flag propio de la fila.
  bool get organizerIsVerified =>
      isFromOrganization ? organizationVerified : organizerVerified;

  /// Nulo en publicaciones personales (`profiles` no tiene handle).
  String? get organizerHandle {
    final handle = organizationHandle;
    if (!isFromOrganization || handle == null || handle.trim().isEmpty) {
      return null;
    }
    return '@$handle';
  }

  String get organizerInitials {
    final parts = organizerDisplayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  /// En vez de un `copyWith` completo: refleja join/leave al instante sin esperar un re-fetch.
  EcoActivityModel withParticipation({
    required bool isJoined,
    required int participantCount,
  }) {
    return EcoActivityModel(
      id: id,
      title: title,
      description: description,
      category: category,
      location: location,
      latitude: latitude,
      longitude: longitude,
      startTime: startTime,
      maxCapacity: maxCapacity,
      organizerId: organizerId,
      organizerName: organizerName,
      organizerVerified: organizerVerified,
      organizationId: organizationId,
      organizationName: organizationName,
      organizationHandle: organizationHandle,
      organizationLogoUrl: organizationLogoUrl,
      organizationVerified: organizationVerified,
      requirements: requirements,
      createdAt: createdAt,
      participantCount: participantCount,
      isJoinedByCurrentUser: isJoined,
    );
  }

  factory EcoActivityModel.fromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    // Embed to-many: lista de {user_id, joined_at}, usada para derivar ambos campos sin un round-trip aparte.
    final participants = (row['eco_participants'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    // Embed to-one: mapa si la jornada tiene organization_id, null si no, ausente si la consulta corrió sin el embed.
    final organization = row['organizations'] as Map<String, dynamic>?;
    return EcoActivityModel(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      category: row['category'] as String? ?? '',
      location: row['location'] as String? ?? '',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startTime: DateTime.parse(row['start_time'] as String),
      maxCapacity: (row['max_capacity'] as num?)?.toInt(),
      organizerId: row['organizer_id'] as String?,
      organizerName: row['organizer_name'] as String?,
      organizerVerified: row['organizer_verified'] as bool? ?? false,
      organizationId:
          row['organization_id'] as String? ?? organization?['id'] as String?,
      organizationName: organization?['name'] as String?,
      organizationHandle: organization?['handle'] as String?,
      organizationLogoUrl: organization?['logo_url'] as String?,
      organizationVerified: organization?['is_verified'] as bool? ?? false,
      requirements:
          (row['requirements'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(row['created_at'] as String),
      participantCount: participants.length,
      isJoinedByCurrentUser:
          currentUserId != null &&
          participants.any((p) => p['user_id'] == currentUserId),
    );
  }
}
