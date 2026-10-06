import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';

/// Un lugar recomendado **ya hidratado** con sus datos reales de Supabase.
///
/// Existe para que las tarjetas del chat no tengan que ramificar entre negocio
/// y jornada ECO en cada campo: el asistente devuelve ids de dos tablas
/// distintas, pero en el chat se pintan igual. Guarda además el modelo de
/// origen ([business]/[activity]) porque las pantallas de detalle lo piden
/// completo.
class AssistantPlace {
  const AssistantPlace({
    required this.id,
    required this.kind,
    required this.name,
    required this.subtitle,
    required this.reason,
    this.imagePath,
    this.latitude,
    this.longitude,
    this.isEco = false,
    this.business,
    this.activity,
  });

  factory AssistantPlace.fromBusiness(BusinessModel business, String reason) {
    return AssistantPlace(
      id: business.id,
      kind: AssistantItemKind.business,
      name: business.name,
      subtitle: [
        business.category,
        business.city,
      ].where((part) => part.isNotEmpty).join(' · '),
      reason: reason,
      imagePath: business.localImagePaths.isNotEmpty
          ? business.localImagePaths.first
          : business.logoUrl,
      latitude: business.latitude,
      longitude: business.longitude,
      isEco: business.ecoSealRequested,
      business: business,
    );
  }

  factory AssistantPlace.fromActivity(
    EcoActivityModel activity,
    String reason,
  ) {
    return AssistantPlace(
      id: activity.id,
      kind: AssistantItemKind.ecoActivity,
      name: activity.title,
      subtitle: [
        'Jornada ECO',
        activity.location,
      ].where((part) => part.isNotEmpty).join(' · '),
      reason: reason,
      imagePath: activity.imageUrl,
      latitude: activity.latitude,
      longitude: activity.longitude,
      // Una jornada siempre es ECO: es la razón de ser de la sección.
      isEco: true,
      activity: activity,
    );
  }

  final String id;
  final AssistantItemKind kind;
  final String name;

  /// Categoría y lugar, ya unidos con separador.
  final String subtitle;

  /// Por qué el asistente lo recomendó.
  final String reason;

  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final bool isEco;

  /// Solo uno de los dos está presente, según [kind].
  final BusinessModel? business;
  final EcoActivityModel? activity;

  /// Sin coordenadas no se puede centrar el mapa ni trazar una ruta, así que
  /// las acciones que dependen de eso se ocultan en vez de fallar al tocarlas.
  bool get hasCoordinates => latitude != null && longitude != null;
}
