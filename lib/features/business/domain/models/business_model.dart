import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';

/// Negocio turístico registrado vía el wizard "Registra tu negocio".
/// [id] es un uuid generado en el cliente (el wizard lo asigna antes del
/// insert). [localImagePaths] guarda URLs públicas del bucket `businesses`
/// (ver `BusinessStorageService.uploadImage` y
/// supabase/sql/022_business_photos_storage.sql) — el nombre quedó de antes
/// de esa migración, cuando eran rutas locales de `image_picker`; negocios
/// registrados antes de la migración pueden seguir teniendo alguna ruta local
/// vieja acá, que `LocalImage` ya sabe degradar a un ícono de reemplazo.
class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.city,
    required this.locationText,
    this.latitude,
    this.longitude,
    required this.contactPhone,
    this.instagramLink = '',
    this.facebookLink = '',
    this.tiktokLink = '',
    this.amenities = const [],
    this.activities = const [],
    this.ecoSealRequested = false,
    this.ecoPractices = const [],
    required this.hostName,
    this.logoUrl,
    this.showHost = true,
    this.ownerId = '',
    this.schedules = '',
    this.accessDetails = '',
    this.otherNotes = '',
    this.localImagePaths = const [],
    this.reviews = const [],
    this.isVerified = false,
    this.reviewStatus = ReviewStatus.pendiente,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String name;
  final String category;
  final String description;

  /// Etiqueta corta de ciudad/municipio (ej. "Masaya"); nunca la dirección completa.
  final String city;

  /// Dirección exacta; solo se muestra en la sección "Mapa de ubicación exacta" del detalle, nunca en tarjetas compactas.
  final String locationText;
  final double? latitude;
  final double? longitude;
  final String contactPhone;
  final String instagramLink;
  final String facebookLink;
  final String tiktokLink;

  final List<String> amenities;
  final List<String> activities;

  /// El dueño se autodeclaró para el "Sello ECO" (Pantalla 4c); no es una insignia verificada por un admin — ver [ecoPractices].
  final bool ecoSealRequested;

  /// Prácticas de sostenibilidad marcadas por el dueño; el wizard exige al menos 2 para mostrar "por verificar", pero es solo un hint de UI, no hay workflow de revisión admin todavía.
  final List<String> ecoPractices;

  final String hostName;

  /// Logo propio de la cara de negocio (bucket `businesses`, mismo que
  /// [localImagePaths]). Nulo cae al avatar con iniciales — nunca a la
  /// primera foto de la galería, esa es la portada del detalle público, no
  /// el logo de la cara.
  final String? logoUrl;

  /// Si es `false`, el bloque "Anfitrión" desaparece del detalle público —
  /// no se reemplaza por el negocio ni por un nombre libre. Cambiar esto no
  /// reabre la revisión: es un dato de presentación, no algo que el equipo
  /// haya verificado.
  final bool showHost;

  /// uuid real de `auth.users.id`; vacío para negocios guardados antes de que existiera auth real. Alimenta "Mis Negocios" y el link a perfil del Anfitrión.
  final String ownerId;
  final String schedules;

  /// Contenido extra de "Mostrar más" (parqueos, senderos, notas), opcional.
  final String accessDetails;
  final String otherNotes;

  final List<String> localImagePaths;
  final List<ReviewModel> reviews;

  /// Solo lectura desde el cliente: nadie en la app escribe `true` aquí (es acción de rol auditor, directo en Supabase).
  final bool isVerified;

  /// Estado de revisión (`businesses.status`). Concepto **paralelo** a
  /// [isVerified], no su reemplazo: `status` decide si el negocio se publica,
  /// [isVerified] sigue siendo el sello de "verificado" que se muestra encima
  /// de un negocio ya publicado.
  ///
  /// Default [ReviewStatus.pendiente] para que un modelo construido en el
  /// wizard (antes de que la base le ponga su default) no se dibuje como si
  /// ya estuviera aprobado.
  final ReviewStatus reviewStatus;

  /// Motivo que escribió quien rechazó; solo tiene valor cuando
  /// [reviewStatus] es [ReviewStatus.rechazado].
  final String? rejectionReason;

  final DateTime? reviewedAt;

  /// `profiles.id` del admin/auditor que revisó — trazabilidad, no se muestra
  /// al dueño.
  final String? reviewedBy;

  double get averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<double>(0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  BusinessModel copyWith({
    String? name,
    String? category,
    String? description,
    String? city,
    String? locationText,
    double? latitude,
    double? longitude,
    String? contactPhone,
    String? instagramLink,
    String? facebookLink,
    String? tiktokLink,
    List<String>? amenities,
    List<String>? activities,
    bool? ecoSealRequested,
    List<String>? ecoPractices,
    String? hostName,
    String? logoUrl,
    bool? showHost,
    String? ownerId,
    String? schedules,
    String? accessDetails,
    String? otherNotes,
    List<String>? localImagePaths,
    List<ReviewModel>? reviews,
    bool? isVerified,
    ReviewStatus? reviewStatus,
    String? rejectionReason,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return BusinessModel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      city: city ?? this.city,
      locationText: locationText ?? this.locationText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactPhone: contactPhone ?? this.contactPhone,
      instagramLink: instagramLink ?? this.instagramLink,
      facebookLink: facebookLink ?? this.facebookLink,
      tiktokLink: tiktokLink ?? this.tiktokLink,
      amenities: amenities ?? this.amenities,
      activities: activities ?? this.activities,
      ecoSealRequested: ecoSealRequested ?? this.ecoSealRequested,
      ecoPractices: ecoPractices ?? this.ecoPractices,
      hostName: hostName ?? this.hostName,
      logoUrl: logoUrl ?? this.logoUrl,
      showHost: showHost ?? this.showHost,
      ownerId: ownerId ?? this.ownerId,
      schedules: schedules ?? this.schedules,
      accessDetails: accessDetails ?? this.accessDetails,
      otherNotes: otherNotes ?? this.otherNotes,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      reviews: reviews ?? this.reviews,
      isVerified: isVerified ?? this.isVerified,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'city': city,
    'locationText': locationText,
    'latitude': latitude,
    'longitude': longitude,
    'contactPhone': contactPhone,
    'instagramLink': instagramLink,
    'facebookLink': facebookLink,
    'tiktokLink': tiktokLink,
    'amenities': amenities,
    'activities': activities,
    'ecoSealRequested': ecoSealRequested,
    'ecoPractices': ecoPractices,
    'hostName': hostName,
    'logoUrl': logoUrl,
    'showHost': showHost,
    'ownerId': ownerId,
    'schedules': schedules,
    'accessDetails': accessDetails,
    'otherNotes': otherNotes,
    'localImagePaths': localImagePaths,
    'reviews': reviews.map((r) => r.toJson()).toList(),
    'isVerified': isVerified,
    'reviewStatus': reviewStatus.wireValue,
    'rejectionReason': rejectionReason,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'reviewedBy': reviewedBy,
  };

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      // Negocios guardados antes del split ciudad/dirección solo tienen locationText; se usa como fallback hasta que el dueño edite.
      city: json['city'] as String? ?? json['locationText'] as String? ?? '',
      locationText: json['locationText'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      contactPhone: json['contactPhone'] as String,
      instagramLink: json['instagramLink'] as String? ?? '',
      facebookLink: json['facebookLink'] as String? ?? '',
      tiktokLink: json['tiktokLink'] as String? ?? '',
      amenities:
          (json['amenities'] as List<dynamic>?)?.cast<String>() ?? const [],
      activities:
          (json['activities'] as List<dynamic>?)?.cast<String>() ?? const [],
      ecoSealRequested: json['ecoSealRequested'] as bool? ?? false,
      ecoPractices:
          (json['ecoPractices'] as List<dynamic>?)?.cast<String>() ?? const [],
      hostName: json['hostName'] as String,
      logoUrl: json['logoUrl'] as String?,
      showHost: json['showHost'] as bool? ?? true,
      ownerId: json['ownerId'] as String? ?? '',
      schedules: json['schedules'] as String? ?? '',
      accessDetails: json['accessDetails'] as String? ?? '',
      otherNotes: json['otherNotes'] as String? ?? '',
      localImagePaths:
          (json['localImagePaths'] as List<dynamic>?)?.cast<String>() ??
          const [],
      reviews:
          (json['reviews'] as List<dynamic>?)
              ?.map((r) => ReviewModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      isVerified: json['isVerified'] as bool? ?? false,
      reviewStatus: ReviewStatus.fromWire(json['reviewStatus']),
      rejectionReason: json['rejectionReason'] as String?,
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
      reviewedBy: json['reviewedBy'] as String?,
    );
  }
}
