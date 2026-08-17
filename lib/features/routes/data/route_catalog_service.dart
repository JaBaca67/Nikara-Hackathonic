import 'package:geolocator/geolocator.dart';

import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/utils/eco_format.dart';
import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';

/// Lo que devuelve [RouteCatalogService.loadCandidates]: los lugares que se
/// pueden agregar a una ruta y, si alguna de las tres fuentes falló, el
/// aviso correspondiente.
///
/// Un fallo parcial no vacía el buscador: que Supabase no responda no
/// debería impedir agregar un punto turístico, pero tampoco se traga en
/// silencio — la pantalla muestra [warning] junto a lo que sí cargó.
typedef RouteCatalog = ({List<RouteStopModel> stops, String? warning});

/// Arma el catálogo de paradas posibles del paso 2 del wizard: negocios
/// registrados, jornadas ECO próximas y puntos turísticos, todos ya
/// convertidos a [RouteStopModel] para que el wizard trabaje con un solo
/// tipo sin importar de dónde salió cada lugar.
class RouteCatalogService {
  factory RouteCatalogService() => RouteCatalogService.instance;

  RouteCatalogService._internal();

  static final RouteCatalogService instance = RouteCatalogService._internal();

  Future<RouteCatalog> loadCandidates() async {
    final stops = <RouteStopModel>[];
    final failures = <String>[];

    // La posición sirve solo para el "· 18 km" del subtítulo. Si no está
    // disponible (permiso denegado, emulador sin GPS) el lugar se muestra
    // igual, con su ciudad sola — nunca con una distancia inventada.
    final position = await LocationService().getCurrentPosition();

    try {
      final businesses = await BusinessStorageService().getBusinesses();
      stops.addAll(
        businesses.map(
          (business) => stopFromBusiness(business, userPosition: position),
        ),
      );
    } on Exception {
      failures.add('los negocios');
    }

    try {
      final activities = await EcoService().getUpcomingActivities();
      stops.addAll(activities.map(stopFromEcoActivity));
    } on EcoServiceException {
      failures.add('las actividades ECO');
    }

    // Los puntos turísticos son estáticos (mock_destinations.dart, la misma
    // fuente que alimenta el Inicio), así que no pueden fallar.
    stops.addAll(mockDestinations.map(stopFromDestination));

    return (
      stops: List<RouteStopModel>.unmodifiable(stops),
      warning: failures.isEmpty
          ? null
          : 'No se pudieron cargar ${failures.join(' ni ')}.',
    );
  }

  /// Un negocio como parada — su categoría libre se reduce a Turístico o
  /// Gastronómico (ver [RouteStopCategory.forBusinessCategory]).
  static RouteStopModel stopFromBusiness(
    BusinessModel business, {
    Position? userPosition,
  }) {
    final distanceKm = LocationService.distanceKm(
      userPosition,
      business.latitude,
      business.longitude,
    );
    final city = business.city.trim();
    return RouteStopModel(
      kind: RouteStopKind.business,
      sourceId: business.id,
      title: business.name,
      subtitle: [
        if (city.isNotEmpty) city,
        if (distanceKm != null) '${distanceKm.toStringAsFixed(0)} km',
      ].join(' · '),
      category: RouteStopCategory.forBusinessCategory(business.category),
      imagePath: business.localImagePaths.isEmpty
          ? null
          : business.localImagePaths.first,
      latitude: business.latitude,
      longitude: business.longitude,
    );
  }

  /// Una jornada ECO como parada — "Managua · 24 may".
  static RouteStopModel stopFromEcoActivity(EcoActivityModel activity) {
    final location = activity.location.trim();
    return RouteStopModel(
      kind: RouteStopKind.ecoActivity,
      sourceId: activity.id,
      title: activity.title,
      subtitle: [
        if (location.isNotEmpty) location,
        formatEcoDayMonth(activity.startTime),
      ].join(' · '),
      category: RouteStopCategory.eco,
      imagePath: activity.organizationLogoUrl,
      latitude: activity.latitude,
      longitude: activity.longitude,
    );
  }

  /// Un punto turístico del Inicio como parada. No tiene coordenadas
  /// todavía (ver `DestinationModel`), así que no aparece en el mini-mapa
  /// del detalle: aparece en el itinerario, que es lo que sí sabemos.
  static RouteStopModel stopFromDestination(DestinationModel destination) {
    return RouteStopModel(
      kind: RouteStopKind.destination,
      sourceId: destination.id,
      title: destination.title,
      subtitle: destination.location,
      category: RouteStopCategory.turistico,
      imagePath: destination.imageAsset,
    );
  }
}
