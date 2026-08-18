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

/// Una persona inscrita en una jornada. `full_name`/`avatar_url` vienen del
/// embed anidado `eco_participants -> profiles`, así que la lista de
/// participantes se dibuja con su foto real y enlaza a su perfil público sin
/// una consulta por persona.
class EcoParticipant {
  const EcoParticipant({
    required this.userId,
    required this.joinedAt,
    this.fullName,
    this.avatarUrl,
  });

  final String userId;
  final DateTime joinedAt;

  /// Nulo si `profiles` no fue legible (invitado) o falta la migración 013.
  final String? fullName;
  final String? avatarUrl;

  String get displayName {
    final name = fullName?.trim();
    return (name == null || name.isEmpty) ? 'Voluntario' : name;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  factory EcoParticipant.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return EcoParticipant(
      userId: row['user_id'] as String,
      joinedAt: DateTime.parse(row['joined_at'] as String),
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

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
    this.imageUrl,
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
    this.participants = const [],
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

  /// Portada única de la jornada: URL pública del bucket `eco_activities` de
  /// Supabase Storage (ver supabase/sql/014_eco_activity_image.sql). La usan
  /// por igual la tarjeta del feed, la tarjeta hero y la portada del detalle;
  /// nula = se cae al ícono de la categoría.
  final String? imageUrl;

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

  /// Inscritos con su nombre y foto, en orden de inscripción. Vacía cuando la
  /// consulta corrió sin el embed anidado de `profiles`; [participantCount] es
  /// siempre confiable aunque esta lo esté.
  final List<EcoParticipant> participants;

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
      imageUrl: imageUrl,
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
      participants: participants,
      participantCount: participantCount,
      isJoinedByCurrentUser: isJoined,
    );
  }

  factory EcoActivityModel.fromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    // Embed to-many: lista de {user_id, joined_at}, usada para derivar ambos campos sin un round-trip aparte.
    final participantRows = (row['eco_participants'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final participants = participantRows
        .map(EcoParticipant.fromRow)
        .toList(growable: false);
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
      // Ausente (no solo nula) mientras no haya corrido la migración 014.
      imageUrl: row['image_url'] as String?,
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
      participants: participants,
      participantCount: participants.length,
      isJoinedByCurrentUser:
          currentUserId != null &&
          participants.any((p) => p.userId == currentUserId),
    );
  }
}
