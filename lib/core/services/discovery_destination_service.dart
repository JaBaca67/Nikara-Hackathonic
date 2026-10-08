import 'package:flutter/foundation.dart';
import 'package:nikara_app/core/models/geographic_destination.dart';

/// Comparte el destino de exploración entre Inicio, Mapa y ECO durante la sesión.
/// No escribe la procedencia del perfil ni modifica la ubicación GPS.
class DiscoveryDestinationService {
  factory DiscoveryDestinationService() => instance;
  DiscoveryDestinationService._internal();
  static final instance = DiscoveryDestinationService._internal();
  final destination = ValueNotifier<GeographicDestination>(
    const GeographicDestination(),
  );
}
