import 'package:flutter/foundation.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';

/// Destination content is separate from visit ownership. The sample does not
/// award points or claim that the current user has visited this place.
@immutable
class TravelPostcard {
  const TravelPostcard({
    required this.id,
    required this.title,
    required this.region,
    required this.message,
    this.artAsset,
    this.imagePath,
    this.category = '',
    this.address = '',
    this.schedules = '',
    this.sealedAt,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String title;
  final String region;
  final String message;
  final String? artAsset;
  final String? imagePath;
  final String category;
  final String address;
  final String schedules;
  final DateTime? sealedAt;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isStamped => sealedAt != null;

  String get sealDateLabel {
    final local = sealedAt!.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String get sealTimeLabel {
    final local = sealedAt!.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  /// This ID selects the current trial business, never a saved user visit.
  /// Its content and photos always come from the public business record.
  static const previewBusinessId = 'd9f91713-cb3b-44ac-9973-9f33ffdc7de1';

  factory TravelPostcard.fromBusiness(
    BusinessModel business, {
    DateTime? sealedAt,
  }) {
    final cover = business.localImagePaths
        .where((path) => path.trim().isNotEmpty)
        .firstOrNull;
    return TravelPostcard(
      id: business.id,
      title: business.name,
      region: business.city,
      message: business.description,
      imagePath: cover,
      category: business.category,
      address: business.locationText,
      schedules: business.schedules,
      sealedAt: sealedAt?.toUtc(),
      latitude: business.latitude,
      longitude: business.longitude,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'region': region,
    'message': message,
    'image_path': imagePath,
    'category': category,
    'address': address,
    'schedules': schedules,
    'latitude': latitude,
    'longitude': longitude,
    'sealed_at': sealedAt?.toUtc().toIso8601String(),
  };

  factory TravelPostcard.fromJson(Map<String, dynamic> json) => TravelPostcard(
    id: json['id'] as String,
    title: json['title'] as String,
    region: json['region'] as String,
    message: json['message'] as String,
    imagePath: json['image_path'] as String?,
    category: json['category'] as String,
    address: json['address'] as String,
    schedules: json['schedules'] as String,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    sealedAt: DateTime.parse(json['sealed_at'] as String).toUtc(),
  );

  static const miraflorExample = TravelPostcard(
    id: 'miraflor',
    title: 'Reserva Natural Miraflor',
    region: 'Estelí',
    message:
        'Bosque nuboso, orquídeas y fincas familiares que ofrecen '
        'hospedaje rural y café de altura.',
    artAsset: 'assets/images/postcard_miraflor.svg',
    latitude: 13.25,
    longitude: -86.25,
  );
}
