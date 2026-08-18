import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';

/// Uno o más negocios agrupados en un mismo marcador: grupo de 1 se dibuja como pin normal, varios como badge numerado.
class MapCluster {
  const MapCluster({required this.position, required this.businesses});

  final LatLng position;
  final List<BusinessModel> businesses;

  bool get isSingle => businesses.length == 1;
  int get count => businesses.length;
}

/// Agrupa [businesses] en una grilla dimensionada con la fórmula Web Mercator de Google Maps (metros por píxel según [zoom]/[referenceLatitude]), así las celdas encogen solas al hacer zoom sin un algoritmo aparte para "separar" pines.
///
/// Es una grilla simple en grados por píxel, no clustering por distancia en pantalla como los SDKs reales, porque el volumen de negocios de Nikara no llega a hacer visibles sus artefactos de borde.
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
