/// The three visual/behavioral states a card or detail screen renders —
/// Estados 1/2/3 of the "fases-pantalla-eco" reference. Derived, never
/// stored: [EcoActivityModel.status] computes it from [EcoActivityModel
/// .startTime] (past = completed) and whether the current user is among
/// [EcoActivityModel.isJoinedByCurrentUser].
enum EcoActivityStatus {
  /// Estado 1 — upcoming, current user hasn't joined. "Unirme" (gold).
  available,

  /// Estado 2 — upcoming, current user already joined. "Abandonar
  /// actividad" (outline) + "Participando" indicator.
  joined,

  /// Estado 3 — start time has passed. Inactive badge, final participant
  /// count shown instead of a join/leave action.
  completed,
}

/// Fixed category set for the filter chips ("Todas, Reforestación, Fauna,
/// Limpieza") and [CreateEcoActivityScreen]'s picker — `eco_activities
/// .category` is still a free-text column (same convention as
/// `businesses.category`), this is just the known/curated set the UI
/// offers instead of a Postgres enum that would need a migration for
/// every new category.
const List<String> kEcoCategories = ['Reforestación', 'Fauna', 'Limpieza'];

/// A row from Supabase's `eco_activities` table, plus the two fields
/// [EcoService] computes alongside it via the embedded `eco_participants`
/// join — [participantCount] and [isJoinedByCurrentUser] — rather than
/// separate round-trips per activity.
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
    this.requirements = const [],
    required this.createdAt,
    this.participantCount = 0,
    this.isJoinedByCurrentUser = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;

  /// Short display label ("Cerro Apante, Managua") — same role as
  /// `BusinessModel.city`, not a full address.
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime startTime;

  /// Null means "no cap" — [spotsAvailable]/[isFull] both read that as
  /// always-open rather than always-full.
  final int? maxCapacity;

  final String? organizerId;
  final String? organizerName;
  final bool organizerVerified;

  /// "Ropa cómoda y botas cerradas", "Botella de agua...", the detail
  /// screen's "Requisitos y qué llevar" checklist and
  /// [CreateEcoActivityScreen]'s requirements field.
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

  /// "Empieza pronto" hero tag — upcoming and starting within a week.
  bool get startsSoon =>
      !isPast && startTime.difference(DateTime.now()).inDays < 7;

  int? get spotsAvailable {
    final cap = maxCapacity;
    if (cap == null) return null;
    final remaining = cap - participantCount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isFull => spotsAvailable == 0;

  /// "Fundación Nicaragua Verde" or a generic fallback for an activity
  /// with no [organizerName] set.
  String get organizerDisplayName =>
      (organizerName == null || organizerName!.trim().isEmpty)
      ? 'Organizador'
      : organizerName!;

  /// Purpose-built instead of a full `copyWith` (nothing else in this app
  /// mutates an already-loaded [EcoActivityModel] locally) — lets
  /// EcoMainScreen/EcoDetailScreen reflect a join/leave in the UI the
  /// instant the tap happens, instead of waiting on a full re-fetch.
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
    // eco_participants is embedded via Postgrest's nested-select syntax
    // (see EcoService._select) as a list of {user_id, joined_at} maps —
    // computing both derived fields from that one embedded list instead
    // of a second round-trip per activity.
    final participants = (row['eco_participants'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
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
