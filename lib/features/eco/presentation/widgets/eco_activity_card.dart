import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_organizer.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_participant_avatars.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_status_badge.dart';
import 'package:nikara_app/features/eco/utils/eco_format.dart';
import 'package:nikara_app/features/eco/utils/eco_icons.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Tarjeta extendida del feed ECO, según la referencia "Estado-disponible-tarjeta".
class EcoActivityCard extends StatelessWidget {
  const EcoActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.showOrganizer = true,
  });

  final EcoActivityModel activity;
  final VoidCallback onTap;

  /// Se apaga en el perfil del organizador: ahí la fila solo llevaría de vuelta al mismo perfil.
  final bool showOrganizer;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.mapControlBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadowSoft,
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 84,
                height: 118,
                child: LocalImage(
                  path: activity.imageUrl,
                  fallbackIcon: ecoCategoryIcon(activity.category),
                  fallbackIconSize: 26,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activity.category.trim().isNotEmpty) ...[
                    _CategoryBadge(label: activity.category),
                    const SizedBox(height: 7),
                  ],
                  Text(
                    activity.title,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.settingsTextDark,
                      fontSize: 15,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showOrganizer) ...[
                    const SizedBox(height: 6),
                    EcoOrganizerRow(
                      activity: activity,
                      onTap: () => openEcoOrganizerProfile(context, activity),
                    ),
                  ],
                  const SizedBox(height: 7),
                  _MetaRow(
                    icon: Icons.place_rounded,
                    text: activity.location.isEmpty
                        ? 'Ubicación por confirmar'
                        : activity.location,
                  ),
                  const SizedBox(height: 4),
                  _MetaRow(
                    icon: Icons.calendar_month_rounded,
                    text: formatEcoDateTimeLong(activity.startTime),
                  ),
                  const SizedBox(height: 11),
                  // Wrap y no Row: en pantallas angostas el pill baja a un segundo renglón en vez de desbordar.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      EcoParticipantAvatars(
                        count: activity.participantCount,
                        participants: activity.participants,
                        size: 28,
                      ),
                      EcoStatusBadge(status: activity.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.detailActivityIconBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.detailEcoBadge.copyWith(
          fontSize: 10,
          letterSpacing: 0.3,
          color: AppColors.ecoActive,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: AppColors.settingsTextMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
