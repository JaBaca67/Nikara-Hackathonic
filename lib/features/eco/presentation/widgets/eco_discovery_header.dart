import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

class EcoDiscoveryHeader extends StatelessWidget {
  const EcoDiscoveryHeader({super.key, required this.availableCount});

  final int? availableCount;

  @override
  Widget build(BuildContext context) {
    final count = availableCount;
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
              Text(
                'Actividades Ambientales',
                style: AppTextStyles.sectionTitle,
              ),
              Text(
                count == null
                    ? 'Descubrí iniciativas ambientales'
                    : '$count ${count == 1 ? 'actividad para explorar' : 'actividades para explorar'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
