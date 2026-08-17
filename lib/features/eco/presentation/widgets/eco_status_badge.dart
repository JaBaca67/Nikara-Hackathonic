import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// "Unido"/"Disponible"/"Completada" pill — the one badge every ECO card
/// and the detail screen's header stat both use, so the 3-state design
/// (Estados 1/2/3 of "fases-pantalla-eco") only lives in one place.
class EcoStatusBadge extends StatelessWidget {
  const EcoStatusBadge({super.key, required this.status});

  final EcoActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, background, foreground, bordered) = switch (status) {
      EcoActivityStatus.joined => (
        'Unido',
        Icons.groups_rounded,
        AppColors.ecoActive,
        AppColors.surface100,
        false,
      ),
      EcoActivityStatus.available => (
        'Disponible',
        Icons.add_circle_outline_rounded,
        AppColors.primary500,
        AppColors.settingsTextDark,
        false,
      ),
      EcoActivityStatus.completed => (
        'Completada',
        Icons.check_circle_outline_rounded,
        AppColors.settingsBackground,
        AppColors.settingsTextMuted,
        true,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: bordered ? Border.all(color: AppColors.mapControlBorder) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.mapRowTitle.copyWith(
              fontSize: 11,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
