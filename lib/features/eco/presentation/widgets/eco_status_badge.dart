import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Único badge de estado compartido por tarjeta y detalle, para que los 3 estados vivan en un solo lugar.
class EcoStatusBadge extends StatelessWidget {
  const EcoStatusBadge({super.key, required this.status});

  final EcoActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, background, foreground, bordered) = switch (status) {
      EcoActivityStatus.available => (
        'Disponible',
        Icons.person_add_alt_1_rounded,
        AppColors.settingsBackground,
        AppColors.settingsTextDark,
        false,
      ),
      EcoActivityStatus.joined => (
        'Participando',
        Icons.groups_rounded,
        AppColors.ecoActive,
        AppColors.surface100,
        false,
      ),
      EcoActivityStatus.completed => (
        'Completada',
        Icons.check_circle_outline_rounded,
        AppColors.surface100,
        AppColors.settingsTextMuted,
        true,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 11,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
