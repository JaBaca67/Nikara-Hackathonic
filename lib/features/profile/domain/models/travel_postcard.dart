import 'package:flutter/foundation.dart';

/// Destination content is separate from visit ownership. The sample does not
/// award points or claim that the current user has visited this place.
@immutable
class TravelPostcard {
  const TravelPostcard({
    required this.id,
    required this.title,
    required this.region,
    required this.message,
    required this.artAsset,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String title;
  final String region;
  final String message;
  final String artAsset;
  final double latitude;
  final double longitude;

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
