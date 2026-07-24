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
    required this.allowsReservations,
    this.price,
    this.amenities = const [],
    required this.hostName,
    this.schedules = '',
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

  final bool allowsReservations;
  final double? price;

  final List<String> amenities;
  final String hostName;
  final String schedules;

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
    bool? allowsReservations,
    double? price,
    List<String>? amenities,
    String? hostName,
    String? schedules,
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
      allowsReservations: allowsReservations ?? this.allowsReservations,
      price: price ?? this.price,
      amenities: amenities ?? this.amenities,
      hostName: hostName ?? this.hostName,
      schedules: schedules ?? this.schedules,
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
    'allowsReservations': allowsReservations,
    'price': price,
    'amenities': amenities,
    'hostName': hostName,
    'schedules': schedules,
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
      allowsReservations: json['allowsReservations'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble(),
      amenities:
          (json['amenities'] as List<dynamic>?)?.cast<String>() ?? const [],
      hostName: json['hostName'] as String,
      schedules: json['schedules'] as String? ?? '',
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
