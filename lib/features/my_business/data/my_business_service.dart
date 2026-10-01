import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/data/review_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/my_business/domain/models/managed_item.dart';

class MyBusinessServiceException implements Exception {
  const MyBusinessServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Qué **categoría de dato** representa una métrica. No es una preferencia
/// estética: es lo que decide su color en la UI, y por eso vive acá y no en el
/// widget.
///
/// - [reputation] — lo que opinan de vos: calificación y reseñas. Se pinta en
///   Gold.
/// - [community] — cuánta gente se involucró: guardados en favoritos,
///   voluntarios, jornadas. Se pinta en Olive.
/// - [inactive] — una métrica que todavía no tiene de dónde salir. Se pinta en
///   neutro apagado, así el color comunica "no disponible" por sí solo y no
///   depende de que alguien lea la leyenda.
enum MetricAccent { reputation, community, inactive }

/// Una tarjeta del grid de métricas o una columna de la fila de estadísticas.
///
/// [comingSoon] no es un placeholder decorativo: marca una métrica que el
/// prototipo pide pero que **no tiene de dónde salir todavía** (vistas de
/// perfil y clics a WhatsApp necesitan una tabla de eventos que no existe).
/// Se muestra apagada y con su leyenda en vez de esconderse, para que el hueco
/// quede a la vista y nadie lea un cero como "nadie te visitó".
class DashboardMetric {
  const DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
    this.comingSoon = false,
  });

  const DashboardMetric.comingSoon({required this.label, required this.icon})
    : value = '—',
      caption = 'Próximamente',
      comingSoon = true,
      accent = MetricAccent.inactive;

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final MetricAccent accent;
  final bool comingSoon;

  /// Etiqueta corta para la fila de estadísticas de la cabecera, donde no
  /// entran dos palabras por columna.
  DashboardMetric withShortLabel(String shortLabel) => DashboardMetric(
    label: shortLabel,
    value: value,
    icon: icon,
    accent: accent,
    caption: caption,
    comingSoon: comingSoon,
  );
}

/// Lo que el dashboard "Mi negocio" necesita: qué administra esta cuenta y qué
/// números mostrar de cada cosa.
///
/// No habla con Postgres directamente: compone los servicios que ya existen
/// (`BusinessStorageService`, `OrganizationService`, `EcoService`,
/// `ReviewService`, `FavoritesService`). Es una capa de agregación, no un
/// acceso a datos nuevo — así las reglas de pertenencia siguen viviendo en un
/// solo lugar por tabla.
class MyBusinessService {
  factory MyBusinessService() => instance;

  MyBusinessService._internal();

  static final MyBusinessService instance = MyBusinessService._internal();

  /// Todo lo que administra la cuenta activa, en el orden del selector:
  /// negocios, después fundaciones, después jornadas.
  ///
  /// Cada fuente falla por separado a propósito. Si el módulo ECO no responde,
  /// el emprendedor tiene que poder seguir administrando su negocio igual — un
  /// dashboard vacío por una consulta caída sería peor que uno incompleto.
  Future<List<ManagedItem>> getManagedItems() async {
    final items = <ManagedItem>[];
    final failures = <String>[];

    try {
      final businesses = await BusinessStorageService().getMyBusinesses();
      items.addAll(businesses.map(ManagedItem.fromBusiness));
    } on BusinessServiceException catch (e) {
      failures.add(e.message);
    }

    try {
      final organizations = await OrganizationService().getMyOrganizations();
      items.addAll(organizations.map(ManagedItem.fromOrganization));
    } on OrganizationServiceException catch (e) {
      failures.add(e.message);
    }

    try {
      final activities = await EcoService().getMyActivities();
      items.addAll(activities.map(ManagedItem.fromActivity));
    } on EcoServiceException catch (e) {
      failures.add(e.message);
    }

    // Solo se propaga el error si no quedó *nada* que mostrar: con una lista
    // parcial la pantalla es útil y el aviso sería ruido.
    if (items.isEmpty && failures.isNotEmpty) {
      throw MyBusinessServiceException(failures.first);
    }
    return items;
  }

  /// Las tres columnas de la fila de estadísticas de la cabecera del perfil de
  /// una cara: los números que **sí** existen hoy.
  ///
  /// Van separadas de [metricsFor] para que ningún dato aparezca dos veces en
  /// la misma pantalla — arriba lo real, abajo lo que todavía no tiene de dónde
  /// salir.
  ///
  /// Un fallo de red devuelve la métrica en su estado vacío en lugar de tumbar
  /// el perfil: los números son un acompañamiento, lo que no puede faltar son
  /// los accesos de edición.
  Future<List<DashboardMetric>> headlineStatsFor(ManagedItem item) {
    return switch (item.kind) {
      ManagedItemKind.business => _businessHeadline(item.id),
      ManagedItemKind.organization => _organizationHeadline(item.id),
      ManagedItemKind.ecoActivity => _activityHeadline(item),
    };
  }

  /// Las tarjetas del grid secundario: por ahora, solo lo que está en
  /// "Próximamente". Se dibujan igual en vez de esconderse para que el hueco
  /// quede a la vista (ver [DashboardMetric]).
  List<DashboardMetric> metricsFor(ManagedItem item) {
    return switch (item.kind) {
      ManagedItemKind.business => const [
        DashboardMetric.comingSoon(
          label: 'Vistas del perfil',
          icon: Icons.visibility_outlined,
        ),
        DashboardMetric.comingSoon(
          label: 'Contactos por WhatsApp',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      ],
      ManagedItemKind.organization => const [
        DashboardMetric.comingSoon(
          label: 'Vistas del perfil',
          icon: Icons.visibility_outlined,
        ),
      ],
      ManagedItemKind.ecoActivity => const [
        DashboardMetric.comingSoon(
          label: 'Vistas de la jornada',
          icon: Icons.visibility_outlined,
        ),
      ],
    };
  }

  Future<List<DashboardMetric>> _businessHeadline(String businessId) async {
    var saved = 0;
    try {
      saved = await FavoritesService().countFavoritesForBusiness(businessId);
    } on FavoritesServiceException {
      // Se muestra 0 en vez de romper: ver la nota del método.
    }

    var summary = RatingSummary.empty;
    try {
      summary = await ReviewService().getSummary(businessId);
    } on ReviewServiceException {
      // Idem.
    }

    return [
      DashboardMetric(
        label: 'Calificación',
        value: summary.isEmpty ? '—' : summary.average.toStringAsFixed(1),
        icon: Icons.star_rounded,
        accent: MetricAccent.reputation,
      ),
      DashboardMetric(
        label: summary.count == 1 ? 'Reseña' : 'Reseñas',
        value: '${summary.count}',
        icon: Icons.rate_review_outlined,
        accent: MetricAccent.reputation,
      ),
      DashboardMetric(
        label: 'Guardados',
        value: '$saved',
        icon: Icons.favorite_rounded,
        accent: MetricAccent.community,
      ),
    ];
  }

  Future<List<DashboardMetric>> _organizationHeadline(
    String organizationId,
  ) async {
    var published = 0;
    var upcoming = 0;
    var volunteers = 0;
    try {
      final activities = await EcoService().getActivitiesByOrganization(
        organizationId,
      );
      published = activities.length;
      upcoming = activities.where((a) => !a.isPast).length;
      volunteers = activities.fold<int>(
        0,
        (sum, a) => sum + a.participantCount,
      );
    } on EcoServiceException {
      // Se muestran en cero: la fundación sigue siendo administrable.
    }

    return [
      DashboardMetric(
        label: 'Jornadas',
        value: '$published',
        icon: Icons.event_available_outlined,
        accent: MetricAccent.community,
      ),
      DashboardMetric(
        label: 'Voluntarios',
        value: '$volunteers',
        icon: Icons.groups_outlined,
        accent: MetricAccent.community,
      ),
      DashboardMetric(
        label: 'Próximas',
        value: '$upcoming',
        icon: Icons.schedule_rounded,
        accent: MetricAccent.community,
      ),
    ];
  }

  /// Los inscritos de una jornada ya vienen contados en el propio modelo (el
  /// embed de `eco_participants`), así que esta es la única fuente del perfil
  /// que no necesita ninguna consulta extra.
  Future<List<DashboardMetric>> _activityHeadline(ManagedItem item) async {
    final activity = item.activity;
    if (activity == null) return const [];
    final spots = activity.spotsAvailable;
    final daysLeft = activity.startTime.difference(DateTime.now()).inDays;

    return [
      DashboardMetric(
        label: 'Inscritos',
        value: '${activity.participantCount}',
        icon: Icons.groups_outlined,
        accent: MetricAccent.community,
      ),
      DashboardMetric(
        label: 'Cupos libres',
        value: spots == null ? '∞' : '$spots',
        icon: Icons.event_seat_outlined,
        accent: MetricAccent.community,
      ),
      DashboardMetric(
        label: activity.isPast ? 'Días atrás' : 'Días para empezar',
        value: activity.isPast
            ? '${-daysLeft}'
            : '${daysLeft < 0 ? 0 : daysLeft}',
        icon: Icons.calendar_today_outlined,
        accent: MetricAccent.community,
      ),
    ];
  }

  /// Devuelve a la cola de revisión lo que fue rechazado, sea del tipo que sea.
  ///
  /// Cada tipo tiene su propio método de reenvío en su servicio (ahí es donde
  /// vive el filtro de dueño); esto solo elige a cuál llamar.
  Future<void> resubmit(ManagedItem item) async {
    try {
      switch (item.kind) {
        case ManagedItemKind.business:
          await BusinessStorageService().resubmitBusiness(item.id);
        case ManagedItemKind.organization:
          await OrganizationService().resubmitOrganization(item.id);
        case ManagedItemKind.ecoActivity:
          await EcoService().resubmitActivity(item.id);
      }
    } on BusinessServiceException catch (e) {
      throw MyBusinessServiceException(e.message);
    } on OrganizationServiceException catch (e) {
      throw MyBusinessServiceException(e.message);
    } on EcoServiceException catch (e) {
      throw MyBusinessServiceException(e.message);
    }
  }
}
