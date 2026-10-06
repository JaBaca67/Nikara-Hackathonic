import 'package:flutter/material.dart';

import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';
import 'package:nikara_app/features/ai_assistant/domain/models/assistant_place.dart';
import 'package:nikara_app/shared/widgets/eco_badge.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Tarjeta de un lugar recomendado, dentro del hilo del chat.
///
/// Tier Funcional bajo la excepción ECO autorizada: el oliva del [EcoBadge]
/// convive con el dorado de las burbujas del usuario porque acá el oliva no
/// decora, **comunica categoría** — es cómo el usuario distingue de un
/// vistazo qué recomendación es ecológica. Mismo argumento que en Inicio y
/// Mapa.
class AssistantRecommendationCard extends StatelessWidget {
  const AssistantRecommendationCard({
    super.key,
    required this.place,
    required this.onOpenProfile,
    required this.onShowOnMap,
  });

  final AssistantPlace place;
  final VoidCallback onOpenProfile;
  final VoidCallback onShowOnMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenProfile,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: LocalImage(
                        path: place.imagePath,
                        fallbackIcon:
                            place.kind == AssistantItemKind.ecoActivity
                            ? Icons.eco_outlined
                            : Icons.storefront_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                place.name,
                                style: AppTextStyles.homeCardTitle.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (place.isEco) ...[
                              const SizedBox(width: AppSpacing.sm),
                              const EcoBadge(),
                            ],
                          ],
                        ),
                        if (place.subtitle.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            place.subtitle,
                            style: AppTextStyles.homeCardLocation.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (place.reason.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            place.reason,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: Icons.person_outline,
                  label: 'Ver perfil',
                  onTap: onOpenProfile,
                ),
              ),
              if (place.hasCoordinates) ...[
                Container(width: 1, height: 40, color: AppColors.border),
                Expanded(
                  child: _CardAction(
                    icon: Icons.map_outlined,
                    label: 'En el mapa',
                    onTap: onShowOnMap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.oliveText),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              label,
              style: AppTextStyles.homeSeeMore.copyWith(
                color: AppColors.oliveText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta del itinerario propuesto, con el botón que lo convierte en una
/// ruta real de "Mis Rutas".
class AssistantItineraryCard extends StatelessWidget {
  const AssistantItineraryCard({
    super.key,
    required this.itinerary,
    required this.placeResolver,
    required this.onSave,
    required this.isSaving,
    required this.isSaved,
  });

  final AssistantItinerary itinerary;

  /// Resuelve el nombre de una parada con los datos ya hidratados. Devuelve
  /// null si ese id no se pudo cargar, y entonces la parada no se pinta.
  final AssistantPlace? Function(String id) placeResolver;

  final VoidCallback onSave;
  final bool isSaving;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_outlined,
                size: 18,
                color: AppColors.oliveText,
                semanticLabel: 'Itinerario propuesto',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  itinerary.title,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final day in itinerary.days) ...[
            Text(
              'Día ${day.day}',
              style: AppTextStyles.homeSectionTitle.copyWith(
                color: AppColors.oliveText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final stop in day.stops)
              Builder(
                builder: (context) {
                  final place = placeResolver(stop.id);
                  if (place == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.oliveFill,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (stop.note.isNotEmpty)
                                Text(
                                  stop.note,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.settingsTextMuted,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (isSaving || isSaved) ? null : onSave,
              style: FilledButton.styleFrom(
                // Gold es el CTA primario de toda la app; acá sigue siéndolo.
                backgroundColor: AppColors.goldFill,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.goldFill.withValues(
                  alpha: 0.5,
                ),
                disabledForegroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Icon(
                      isSaved ? Icons.check : Icons.bookmark_add_outlined,
                      size: 18,
                    ),
              label: Text(
                isSaved ? 'Guardada en Mis Rutas' : 'Guardar como ruta',
                style: AppTextStyles.buttonMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
