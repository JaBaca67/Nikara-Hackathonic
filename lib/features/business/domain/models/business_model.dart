import 'package:nikara_app/features/business/domain/models/review_model.dart';

/// Negocio turístico registrado vía el wizard "Registra tu negocio".
/// [id] es un uuid generado en el cliente (el wizard lo asigna antes del
/// insert); [localImagePaths] son rutas locales guardadas como strings en
/// `photos` porque no hay object storage real todavía.
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
    this.socialMediaLink = '',
    this.instagramLink = '',
    this.facebookLink = '',
    this.tiktokLink = '',
    required this.allowsReservations,
    this.price,
    this.amenities = const [],
    this.activities = const [],
    this.ecoSealRequested = false,
    this.ecoPractices = const [],
    required this.hostName,
    this.ownerId = '',
    this.schedules = '',
    this.accessDetails = '',
    this.otherNotes = '',
    this.localImagePaths = const [],
    this.reviews = const [],
    this.isVerified = false,
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
  final String socialMediaLink;
  final String instagramLink;
  final String facebookLink;
  final String tiktokLink;

  final bool allowsReservations;
  final double? price;

  final List<String> amenities;
  final List<String> activities;

  /// El dueño se autodeclaró para el "Sello ECO" (Pantalla 4c); no es una insignia verificada por un admin — ver [ecoPractices].
  final bool ecoSealRequested;

  /// Prácticas de sostenibilidad marcadas por el dueño; el wizard exige al menos 2 para mostrar "por verificar", pero es solo un hint de UI, no hay workflow de revisión admin todavía.
  final List<String> ecoPractices;

  final String hostName;

  /// uuid real de `auth.users.id`; vacío para negocios guardados antes de que existiera auth real. Alimenta "Mis Negocios" y el link a perfil del Anfitrión.
  final String ownerId;
  final String schedules;

  /// Contenido extra de "Mostrar más" (parqueos, senderos, notas); a diferencia de [description], el wizard aún no lo recolecta, por eso está vacío en todo negocio actual.
  final String accessDetails;
  final String otherNotes;

  final List<String> localImagePaths;
  final List<ReviewModel> reviews;

  /// Solo lectura desde el cliente: nadie en la app escribe `true` aquí (es acción de rol auditor, directo en Supabase).
  final bool isVerified;

  double get averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<double>(0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  String get formattedPrice =>
      price == null ? '' : 'C\$ ${price!.toStringAsFixed(0)}';

  BusinessModel copyWith({
    String? name,
    String? category,
    String? description,
    String? city,
    String? locationText,
    double? latitude,
    double? longitude,
    String? contactPhone,
    String? socialMediaLink,
    String? instagramLink,
    String? facebookLink,
    String? tiktokLink,
    bool? allowsReservations,
    double? price,
    List<String>? amenities,
    List<String>? activities,
    bool? ecoSealRequested,
    List<String>? ecoPractices,
    String? hostName,
    String? ownerId,
    String? schedules,
    String? accessDetails,
    String? otherNotes,
    List<String>? localImagePaths,
    List<ReviewModel>? reviews,
    bool? isVerified,
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
      socialMediaLink: socialMediaLink ?? this.socialMediaLink,
      instagramLink: instagramLink ?? this.instagramLink,
      facebookLink: facebookLink ?? this.facebookLink,
      tiktokLink: tiktokLink ?? this.tiktokLink,
      allowsReservations: allowsReservations ?? this.allowsReservations,
      price: price ?? this.price,
      amenities: amenities ?? this.amenities,
      activities: activities ?? this.activities,
      ecoSealRequested: ecoSealRequested ?? this.ecoSealRequested,
      ecoPractices: ecoPractices ?? this.ecoPractices,
      hostName: hostName ?? this.hostName,
      ownerId: ownerId ?? this.ownerId,
      schedules: schedules ?? this.schedules,
      accessDetails: accessDetails ?? this.accessDetails,
      otherNotes: otherNotes ?? this.otherNotes,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      reviews: reviews ?? this.reviews,
      isVerified: isVerified ?? this.isVerified,
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
    'socialMediaLink': socialMediaLink,
    'instagramLink': instagramLink,
    'facebookLink': facebookLink,
    'tiktokLink': tiktokLink,
    'allowsReservations': allowsReservations,
    'price': price,
    'amenities': amenities,
    'activities': activities,
    'ecoSealRequested': ecoSealRequested,
    'ecoPractices': ecoPractices,
    'hostName': hostName,
    'ownerId': ownerId,
    'schedules': schedules,
    'accessDetails': accessDetails,
    'otherNotes': otherNotes,
    'localImagePaths': localImagePaths,
    'reviews': reviews.map((r) => r.toJson()).toList(),
    'isVerified': isVerified,
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
      socialMediaLink: json['socialMediaLink'] as String? ?? '',
      instagramLink: json['instagramLink'] as String? ?? '',
      facebookLink: json['facebookLink'] as String? ?? '',
      tiktokLink: json['tiktokLink'] as String? ?? '',
      allowsReservations: json['allowsReservations'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble(),
      amenities:
          (json['amenities'] as List<dynamic>?)?.cast<String>() ?? const [],
      activities:
          (json['activities'] as List<dynamic>?)?.cast<String>() ?? const [],
      ecoSealRequested: json['ecoSealRequested'] as bool? ?? false,
      ecoPractices:
          (json['ecoPractices'] as List<dynamic>?)?.cast<String>() ?? const [],
      hostName: json['hostName'] as String,
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
    );
  }
}
