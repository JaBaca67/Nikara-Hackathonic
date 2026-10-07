import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

class MapBusinessRating extends StatelessWidget {
  const MapBusinessRating({
    super.key,
    required this.average,
    required this.count,
  });

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 0
        ? 'Sin reseñas'
        : '${average.toStringAsFixed(1)} · $count ${count == 1 ? 'reseña' : 'reseñas'}';
    return Semantics(
      label: count == 0 ? label : '$label. Valoración sobre 5 estrellas.',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var star = 0; star < 5; star++)
            Icon(
              count == 0 || average - star < 0.25
                  ? Icons.star_border_rounded
                  : average - star < 0.75
                  ? Icons.star_half_rounded
                  : Icons.star_rounded,
              size: 14,
              color: count == 0
                  ? AppColors.settingsTextMuted
                  : AppColors.goldFill,
            ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.settingsTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
