import 'package:geolocator/geolocator.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';

List<BusinessModel> nearbyBusinesses(
  List<BusinessModel> businesses,
  Position position, {
  int limit = 6,
}) {
  final distances = <String, double>{};
  final nearby = businesses.where((business) {
    final distance = LocationService.distanceKm(
      position,
      business.latitude,
      business.longitude,
    );
    if (distance == null) return false;
    distances[business.id] = distance;
    return true;
  }).toList();
  nearby.sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!));
  return nearby.take(limit).toList(growable: false);
}
