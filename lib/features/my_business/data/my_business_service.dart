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

/// Una tarjeta del grid de métricas del dashboard.
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
    this.caption,
    this.comingSoon = false,
  });

  const DashboardMetric.comingSoon({required this.label, required this.icon})
    : value = '—',
      caption = 'Próximamente',
      comingSoon = true;

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final bool comingSoon;
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

  /// Las cuatro métricas de la cabecera, según qué se esté mirando.
  ///
  /// Un fallo de red devuelve la métrica en su estado vacío en lugar de tumbar
  /// el dashboard: las tarjetas son un acompañamiento, lo que no puede faltar
  /// es el estado de revisión y los accesos de edición.
  Future<List<DashboardMetric>> metricsFor(ManagedItem item) {
    return switch (item.kind) {
      ManagedItemKind.business => _businessMetrics(item.id),
      ManagedItemKind.organization => _organizationMetrics(item.id),
      ManagedItemKind.ecoActivity => _activityMetrics(item),
    };
  }

  Future<List<DashboardMetric>> _businessMetrics(String businessId) async {
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
      const DashboardMetric.comingSoon(
        label: 'Vistas del perfil',
        icon: Icons.visibility_outlined,
      ),
      const DashboardMetric.comingSoon(
        label: 'Contactos por WhatsApp',
        icon: Icons.chat_bubble_outline_rounded,
      ),
      DashboardMetric(
        label: 'Guardados por viajeros',
        value: '$saved',
        icon: Icons.favorite_border_rounded,
      ),
      DashboardMetric(
        label: 'Calificación',
        value: summary.isEmpty ? '—' : summary.average.toStringAsFixed(1),
        caption: summary.isEmpty
            ? 'Sin reseñas todavía'
            : '${summary.count} '
                  '${summary.count == 1 ? 'reseña' : 'reseñas'}',
        icon: Icons.star_border_rounded,
      ),
    ];
  }

  Future<List<DashboardMetric>> _organizationMetrics(
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
        label: 'Jornadas publicadas',
        value: '$published',
        icon: Icons.event_available_outlined,
      ),
      DashboardMetric(
        label: 'Voluntarios inscritos',
        value: '$volunteers',
        caption: 'En todas tus jornadas',
        icon: Icons.groups_outlined,
      ),
      DashboardMetric(
        label: 'Jornadas próximas',
        value: '$upcoming',
        icon: Icons.schedule_rounded,
      ),
      const DashboardMetric.comingSoon(
        label: 'Vistas del perfil',
        icon: Icons.visibility_outlined,
      ),
    ];
  }

  /// Los inscritos de una jornada ya vienen contados en el propio modelo (el
  /// embed de `eco_participants`), así que esta es la única métrica del
  /// dashboard que no necesita ninguna consulta extra.
  Future<List<DashboardMetric>> _activityMetrics(ManagedItem item) async {
    final activity = item.activity;
    if (activity == null) return const [];
    final spots = activity.spotsAvailable;
    final daysLeft = activity.startTime.difference(DateTime.now()).inDays;

    return [
      DashboardMetric(
        label: 'Voluntarios inscritos',
        value: '${activity.participantCount}',
        icon: Icons.groups_outlined,
      ),
      DashboardMetric(
        label: 'Cupos libres',
        value: spots == null ? '∞' : '$spots',
        caption: spots == null ? 'Sin límite de cupo' : null,
        icon: Icons.event_seat_outlined,
      ),
      DashboardMetric(
        label: activity.isPast ? 'Finalizó hace' : 'Empieza en',
        value: activity.isPast
            ? '${-daysLeft}'
            : '${daysLeft < 0 ? 0 : daysLeft}',
        caption: 'días',
        icon: Icons.calendar_today_outlined,
      ),
      const DashboardMetric.comingSoon(
        label: 'Vistas de la jornada',
        icon: Icons.visibility_outlined,
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
