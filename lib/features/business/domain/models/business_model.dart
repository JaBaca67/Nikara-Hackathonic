import 'package:nikara_app/features/business/domain/models/review_model.dart';

/// A tourism business registered locally through the "Registra tu negocio"
/// wizard. Everything is device-local/mock — there is no backend, so
/// [id] is a client-generated uuid and photos are on-device file paths
/// rather than uploaded URLs.
class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
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
    required this.hostName,
    this.schedules = '',
    this.accessDetails = '',
    this.otherNotes = '',
    this.localImagePaths = const [],
    this.reviews = const [],
  });

  final String id;
  final String name;
  final String category;
  final String description;

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
  final String hostName;
  final String schedules;

  /// Extra "Mostrar más" description content — parqueos/senderos/zonas
  /// comunes and any other notes worth calling out (bring cash, weather,
  /// etc). Both are optional and, unlike [description], aren't collected
  /// by the wizard yet, so they're empty for every business created today.
  final String accessDetails;
  final String otherNotes;

  final List<String> localImagePaths;
  final List<ReviewModel> reviews;

  double get averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<double>(0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  String get formattedPrice =>
      price == null ? '' : 'C\$${price!.toStringAsFixed(0)}';

  BusinessModel copyWith({
    String? name,
    String? category,
    String? description,
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
    String? hostName,
    String? schedules,
    String? accessDetails,
    String? otherNotes,
    List<String>? localImagePaths,
    List<ReviewModel>? reviews,
  }) {
    return BusinessModel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
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
      hostName: hostName ?? this.hostName,
      schedules: schedules ?? this.schedules,
      accessDetails: accessDetails ?? this.accessDetails,
      otherNotes: otherNotes ?? this.otherNotes,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      reviews: reviews ?? this.reviews,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
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
    'hostName': hostName,
    'schedules': schedules,
    'accessDetails': accessDetails,
    'otherNotes': otherNotes,
    'localImagePaths': localImagePaths,
    'reviews': reviews.map((r) => r.toJson()).toList(),
  };

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
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
      hostName: json['hostName'] as String,
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
    );
  }
}
