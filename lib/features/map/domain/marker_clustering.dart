import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';

/// One or more businesses grouped into a single map marker — a plain group
/// of 1 (render as the normal pin) once [clusterBusinesses] separates
/// nearby points wide enough apart, or several (render as a numbered
/// cluster badge) when they're closer together than [MapScreen] can show
/// as distinct pins at the current zoom.
class MapCluster {
  const MapCluster({required this.position, required this.businesses});

  final LatLng position;
  final List<BusinessModel> businesses;

  bool get isSingle => businesses.length == 1;
  int get count => businesses.length;
}

/// Grid-based clustering: buckets [businesses] into cells sized in real
/// meters-per-pixel at the given [zoom]/[referenceLatitude] (the same
/// Web Mercator formula Google Maps itself uses to convert zoom level to
/// ground resolution), so cells shrink automatically as the user zooms in
/// and pins naturally "split apart" instead of needing a second algorithm
/// for that. A cluster's marker sits at its members' centroid.
///
/// This is a plain degrees-per-pixel grid rather than the more precise
/// (and much more expensive) screen-space distance clustering real mapping
/// SDKs use — acceptable here since Nikara's business count is nowhere
/// near the scale where the grid's boundary artifacts (two points just
/// across a cell edge staying unclustered) would be visible or matter.
List<MapCluster> clusterBusinesses({
  required List<BusinessModel> businesses,
  required double zoom,
  required double referenceLatitude,
  double pixelRadius = 55,
}) {
  if (businesses.isEmpty) return const [];

  final metersPerPixel =
      156543.03392 * cos(referenceLatitude * pi / 180) / pow(2, zoom);
  final cellSizeDeg = (metersPerPixel * pixelRadius) / 111320;

  if (!cellSizeDeg.isFinite || cellSizeDeg <= 0) {
    return [
      for (final business in businesses)
        MapCluster(
          position: LatLng(business.latitude!, business.longitude!),
          businesses: [business],
        ),
    ];
  }

  final buckets = <String, List<BusinessModel>>{};
  for (final business in businesses) {
    final cellLat = (business.latitude! / cellSizeDeg).floor();
    final cellLng = (business.longitude! / cellSizeDeg).floor();
    (buckets['$cellLat:$cellLng'] ??= []).add(business);
  }

  return [
    for (final group in buckets.values)
      if (group.length == 1)
        MapCluster(
          position: LatLng(group.first.latitude!, group.first.longitude!),
          businesses: group,
        )
      else
        MapCluster(
          position: LatLng(
            group.map((b) => b.latitude!).reduce((a, b) => a + b) /
                group.length,
            group.map((b) => b.longitude!).reduce((a, b) => a + b) /
                group.length,
          ),
          businesses: group,
        ),
  ];
}
