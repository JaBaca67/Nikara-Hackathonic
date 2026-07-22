import 'package:flutter/material.dart';

import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Large hero card for the featured destination at the top of Home
/// (Figma node 124:87, "Laguna de Apoyo").
class FeaturedDestinationCard extends StatelessWidget {
  const FeaturedDestinationCard({
    super.key,
    required this.destination,
    this.onDetailTap,
  });

  final DestinationModel destination;
  final VoidCallback? onDetailTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            destination.imageAsset != null
                ? Image.asset(destination.imageAsset!, fit: BoxFit.cover)
                : ColoredBox(color: destination.imagePlaceholderColor),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    AppColors.neutral900.withValues(alpha: 0.15),
                    AppColors.neutral900.withValues(alpha: 0.35),
                    AppColors.neutral900.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
            if (destination.tag != null)
              Positioned(
                left: 16,
                top: 18,
                child: _Pill(
                  color: AppColors.tagGold600,
                  textColor: AppColors.neutral1100,
                  label: destination.tag!,
                ),
              ),
            const Positioned(
              right: 16,
              top: 16,
              child: _EcoBadge(),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(destination.title, style: AppTextStyles.heroTitle),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: AppColors.surface100,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                destination.location,
                                style: AppTextStyles.heroLocation,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            destination.formattedPrice,
                            style: AppTextStyles.heroPrice,
                          ),
                          Text('/p', style: AppTextStyles.heroLocation),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        _Thumbnail(
                          color: Color.lerp(
                            destination.imagePlaceholderColor,
                            Colors.white,
                            i * 0.15,
                          )!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: onDetailTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            'Ver detalle →',
                            style: AppTextStyles.ctaPill,
                          ),
                        ),
                      ),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral800, width: 1.6),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.color,
    required this.textColor,
    required this.label,
  });

  final Color color;
  final Color textColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.tagPill.copyWith(fontSize: 11, color: textColor),
      ),
    );
  }
}

class _EcoBadge extends StatelessWidget {
  const _EcoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ecoGreen500,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco, size: 10, color: AppColors.surface100),
          const SizedBox(width: 4),
          Text('ECO', style: AppTextStyles.tagPill),
        ],
      ),
    );
  }
}
