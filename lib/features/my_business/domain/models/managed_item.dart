import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';

/// Las tres cosas que una cuenta puede administrar desde "Mi negocio".
enum ManagedItemKind {
  business('Negocio', Icons.storefront_rounded),
  organization('Fundación', Icons.diversity_3_rounded),
  ecoActivity('Jornada ECO', Icons.eco_rounded);

  const ManagedItemKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Fachada común sobre [BusinessModel], [OrganizationModel] y
/// [EcoActivityModel] para el selector y la cabecera del dashboard.
///
/// Existe porque los tres modelos no comparten ni un solo nombre de campo
/// (`name`/`title`, `category`/`handle`/`startTime`,
/// `localImagePaths`/`logoUrl`/`imageUrl`) pero sí comparten exactamente lo que
/// esta pantalla necesita mostrar arriba: cómo se llama, qué es, en qué estado
/// de revisión está y por qué lo rechazaron. Sin esta capa, la cabecera y el
/// selector tendrían un `switch` sobre el tipo en cada línea.
///
/// Guarda además el modelo original ([business], [organization], [activity])
/// porque las acciones —editar, reenviar, eliminar— sí necesitan el tipo
/// concreto.
class ManagedItem {
  const ManagedItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.subtitle,
    required this.reviewStatus,
    this.rejectionReason,
    this.isVerified = false,
    this.imagePath,
    this.business,
    this.organization,
    this.activity,
  });

  final String id;
  final ManagedItemKind kind;
  final String name;

  /// Segunda línea de la tarjeta: la categoría de un negocio, el handle de una
  /// fundación, la fecha de una jornada.
  final String subtitle;

  final ReviewStatus reviewStatus;
  final String? rejectionReason;

  /// El sello "confirmado por Níkara", independiente de [reviewStatus].
  final bool isVerified;

  /// Ruta local o URL de la miniatura; nula se dibuja con el ícono del tipo.
  final String? imagePath;

  final BusinessModel? business;
  final OrganizationModel? organization;
  final EcoActivityModel? activity;

  /// Solo el dueño puede reenviar, y solo lo que fue rechazado.
  bool get canResubmit => reviewStatus.isRechazado;

  factory ManagedItem.fromBusiness(BusinessModel business) {
    return ManagedItem(
      id: business.id,
      kind: ManagedItemKind.business,
      name: business.name.isEmpty ? 'Negocio sin nombre' : business.name,
      subtitle: business.category.isEmpty ? 'Sin categoría' : business.category,
      reviewStatus: business.reviewStatus,
      rejectionReason: business.rejectionReason,
      isVerified: business.isVerified,
      imagePath: business.localImagePaths.isEmpty
          ? null
          : business.localImagePaths.first,
      business: business,
    );
  }

  factory ManagedItem.fromOrganization(OrganizationModel organization) {
    return ManagedItem(
      id: organization.id,
      kind: ManagedItemKind.organization,
      name: organization.name.isEmpty ? 'Fundación' : organization.name,
      subtitle: organization.handleTag,
      reviewStatus: organization.reviewStatus,
      rejectionReason: organization.rejectionReason,
      isVerified: organization.isVerified,
      imagePath: organization.logoUrl,
      organization: organization,
    );
  }

  factory ManagedItem.fromActivity(EcoActivityModel activity) {
    final start = activity.startTime.toLocal();
    final date =
        '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}/${start.year}';
    return ManagedItem(
      id: activity.id,
      kind: ManagedItemKind.ecoActivity,
      name: activity.title.isEmpty ? 'Jornada sin título' : activity.title,
      subtitle: activity.isPast ? 'Finalizada · $date' : date,
      reviewStatus: activity.reviewStatus,
      rejectionReason: activity.rejectionReason,
      imagePath: activity.imageUrl,
      activity: activity,
    );
  }
}
