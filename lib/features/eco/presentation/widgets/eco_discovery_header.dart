import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

class EcoDiscoveryHeader extends StatelessWidget {
  const EcoDiscoveryHeader({super.key, required this.availableCount});

  final int? availableCount;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 330 ||
          MediaQuery.textScalerOf(context).scale(12) > 16;
      final count = availableCount;
      final badge = count == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.oliveFill.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '$count ${count == 1 ? 'disponible' : 'disponibles'}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.oliveFill.withValues(alpha: 0.30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_rounded,
              size: 26,
              color: AppColors.oliveText,
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
                        'Actividades Ambientales',
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    if (!compact && badge != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      badge,
                    ],
                  ],
                ),
                Text(
                  count == null
                      ? 'Descubrí iniciativas ambientales'
                      : '$count ${count == 1 ? 'iniciativa verificada' : 'iniciativas verificadas'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
                if (compact && badge != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  badge,
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}
