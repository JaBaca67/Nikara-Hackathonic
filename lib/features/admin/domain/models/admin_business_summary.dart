import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/utils/search_normalize.dart';

/// Vista reducida de una fila de `businesses` para la cola de revisión.
///
/// No reusa `BusinessModel` a propósito: aquel modelo fusiona campos que solo
/// existen en el cache local del dispositivo del dueño (precio, amenidades,
/// horarios) y parsea el `geography` del mapa. Un auditor revisa desde otro
/// dispositivo, así que ese cache nunca existiría para él: pedir el modelo
/// completo devolvería campos vacíos y haría creer que el negocio está peor
/// cargado de lo que está. Acá solo entra lo que la propia tabla garantiza.
class AdminBusinessSummary {
  const AdminBusinessSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.city,
    required this.addressText,
    required this.phone,
    required this.instagramHandle,
    required this.facebookHandle,
    required this.schedules,
    required this.photos,
    required this.ownerId,
    required this.isVerified,
    this.reviewStatus = ReviewStatus.pendiente,
    this.rejectionReason,
    this.reviewedAt,
    this.createdAt,
    this.ownerName = '',
    this.ownerEmail = '',
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String city;
  final String addressText;
  final String phone;
  final String instagramHandle;
  final String facebookHandle;
  final String schedules;
  final List<String> photos;
  final String ownerId;

  /// `businesses.is_verified` — el sello de "confirmado por Níkara".
  ///
  /// Sigue siendo un eje **aparte** de [reviewStatus]: aquél decide si el
  /// negocio se publica, éste si además lleva sello una vez publicado. Un
  /// negocio aprobado sin sello es un caso normal, no un estado intermedio.
  final bool isVerified;

  /// `businesses.status` — lo que decide si el negocio aparece en la app.
  /// Solo se escribe por el RPC `review_business`, nunca con un `update`.
  final ReviewStatus reviewStatus;

  /// Motivo con el que se rechazó; con valor solo si [reviewStatus] es
  /// [ReviewStatus.rechazado].
  final String? rejectionReason;

  final DateTime? reviewedAt;

  final DateTime? createdAt;

  /// Vienen del join anidado con `profiles`; quedan vacíos si el perfil del
  /// dueño ya no existe (la FK es `on delete cascade`, pero un negocio
  /// sembrado por SQL puede tener `owner_id` nulo).
  final String ownerName;
  final String ownerEmail;

  /// Etiqueta de ubicación con fallback: negocios viejos guardaron todo en
  /// `address_text` antes del split ciudad/dirección.
  String get locationLabel {
    final parts = [
      city.trim(),
      addressText.trim(),
    ].where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Sin ubicación registrada';
    return parts.join(' · ');
  }

  String get ownerLabel {
    final name = ownerName.trim();
    if (name.isNotEmpty) return name;
    final email = ownerEmail.trim();
    if (email.isNotEmpty) return email;
    return 'Dueño desconocido';
  }

  /// Compara [query] contra nombre, categoría, ciudad y dueño — el buscador
  /// del panel (cola de revisión y drill-down de métricas) filtra con esto en
  /// vez de repetir la comparación en cada pantalla. Ignora tildes en ambos
  /// lados (ver [normalizeForSearch]): sin esto, buscar "Rosquilleria" sin la
  /// tilde no encontraba "Rosquillería".
  bool matchesQuery(String query) {
    final q = normalizeForSearch(query.trim());
    if (q.isEmpty) return true;
    return normalizeForSearch(name).contains(q) ||
        normalizeForSearch(category).contains(q) ||
        normalizeForSearch(city).contains(q) ||
        normalizeForSearch(ownerLabel).contains(q);
  }

  AdminBusinessSummary copyWith({
    bool? isVerified,
    ReviewStatus? reviewStatus,
    String? rejectionReason,
    DateTime? reviewedAt,
  }) => AdminBusinessSummary(
    id: id,
    name: name,
    category: category,
    description: description,
    city: city,
    addressText: addressText,
    phone: phone,
    instagramHandle: instagramHandle,
    facebookHandle: facebookHandle,
    schedules: schedules,
    photos: photos,
    ownerId: ownerId,
    isVerified: isVerified ?? this.isVerified,
    reviewStatus: reviewStatus ?? this.reviewStatus,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    createdAt: createdAt,
    ownerName: ownerName,
    ownerEmail: ownerEmail,
  );

  factory AdminBusinessSummary.fromRow(Map<String, dynamic> row) {
    // `profiles` llega como mapa anidado por el join `owner:profiles(...)`;
    // es null si la fila no tiene dueño (seeds de prototipo).
    final owner = row['owner'];
    final ownerMap = owner is Map<String, dynamic> ? owner : null;
    return AdminBusinessSummary(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      category: row['category'] as String? ?? '',
      description: row['description'] as String? ?? '',
      city: row['city'] as String? ?? '',
      addressText: row['address_text'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      instagramHandle: row['instagram_handle'] as String? ?? '',
      // Ausentes (no vacías) mientras no haya corrido la migración 018.
      facebookHandle: row['facebook_handle'] as String? ?? '',
      schedules: row['schedules'] as String? ?? '',
      photos: (row['photos'] as List<dynamic>?)?.cast<String>() ?? const [],
      ownerId: row['owner_id'] as String? ?? '',
      isVerified: row['is_verified'] as bool? ?? false,
      reviewStatus: ReviewStatus.fromWire(row['status']),
      rejectionReason: row['rejection_reason'] as String?,
      reviewedAt: DateTime.tryParse(row['reviewed_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      ownerName: ownerMap?['full_name'] as String? ?? '',
      ownerEmail: ownerMap?['email'] as String? ?? '',
    );
  }
}
