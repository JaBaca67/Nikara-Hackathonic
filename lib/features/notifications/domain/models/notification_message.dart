import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/utils/eco_format.dart';
import 'package:nikara_app/features/notifications/domain/models/app_notification.dart';

/// Mensajes preparados; los nombres, fechas y destinos salen del catálogo.
class NotificationMessage {
  const NotificationMessage({
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
  });

  final String title;
  final String body;
  final NotificationType type;
  final String? referenceId;

  Map<String, dynamic> toRow(String userId) => {
    'user_id': userId,
    'title': title,
    'body': body,
    'type': type.wireValue,
    'reference_id': referenceId,
    'is_read': false,
  };

  static const welcome = [
    NotificationMessage(
      title: '¡Bienvenido a Níkara!',
      body:
          'Tu próxima aventura empieza aquí. Descubre negocios locales, '
          'guarda tus favoritos y participa en actividades que cuidan Nicaragua.',
      type: NotificationType.demoWelcome,
    ),
    NotificationMessage(
      title: 'Tu próxima aventura puede dejar huella',
      body:
          'Explora las jornadas ECO y elige una causa que te inspire. '
          'Al unirte recibirás la confirmación y las indicaciones para participar.',
      type: NotificationType.system,
    ),
  ];

  static List<NotificationMessage> participation(EcoActivityModel activity) {
    final location = activity.location.trim();
    final when = formatEcoDateTimeLong(activity.startTime.toLocal());
    final requirements = activity.requirements
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .join('; ');
    return [
      NotificationMessage(
        title: '¡Ya eres parte de la jornada!',
        body:
            'Te uniste a "${activity.title}". Te esperamos el $when'
            '${location.isEmpty ? '.' : ' en $location.'} '
            '¡Gracias por aportar a una Nicaragua más verde!',
        type: NotificationType.ecoActivityJoined,
        referenceId: activity.id,
      ),
      NotificationMessage(
        title: 'Prepárate para tu actividad ECO',
        body: requirements.isEmpty
            ? 'Antes de participar en "${activity.title}", revisa el punto de '
                  'encuentro y las indicaciones en el detalle de la jornada.'
            : 'Para "${activity.title}": $requirements. '
                  'Consulta todas las indicaciones en el detalle de la jornada.',
        type: NotificationType.ecoActivityPreparation,
        referenceId: activity.id,
      ),
    ];
  }

  static List<NotificationMessage> recommendations(
    List<BusinessModel> businesses,
  ) {
    final seen = <String>{};
    final approved = businesses
        .where(
          (business) =>
              business.reviewStatus == ReviewStatus.aprobado &&
              business.id.isNotEmpty &&
              business.name.trim().isNotEmpty &&
              seen.add(business.id),
        )
        .take(3);
    const titles = [
      'Un negocio local para descubrir',
      'Una nueva parada para tu viaje',
      'Apoya el talento local',
    ];
    var index = 0;
    return [
      for (final business in approved)
        NotificationMessage(
          title: titles[index++],
          body:
              'Conoce "${business.name}"'
              '${business.city.trim().isEmpty ? '' : ' en ${business.city.trim()}'}'
              '. ${business.category.trim().isEmpty ? '' : '${business.category.trim()}. '}'
              'Explora su perfil, revisa lo que ofrece y guárdalo para tu próxima visita.',
          type: NotificationType.businessRecommendation,
          referenceId: business.id,
        ),
    ];
  }
}
