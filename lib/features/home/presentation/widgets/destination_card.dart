import 'package:flutter/material.dart';

import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Reusable vertical card for the "Más visitados" and "Por región" rows
/// (Figma nodes 124:142 / 124:373). [width] switches between the two sizes
/// those sections use (168 / 144).
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.destination,
    this.width = 168,
    this.onTap,
    this.onFavoriteTap,
  });

  final DestinationModel destination;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final imageHeight = width * (110 / 168);

    return Semantics(
      button: true,
      label: '${destination.title}, ${destination.location}',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24FDBE02),
                  offset: Offset(0, 4),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CardImage(destination: destination),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.neutral1100.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        if (destination.tag != null)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: _TagPill(label: destination.tag!),
                          ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: _FavoriteButton(onTap: onFavoriteTap),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: _RatingBadge(rating: destination.rating),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.title,
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 10,
                            color: AppColors.neutral700,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              destination.location,
                              style: AppTextStyles.cardLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            destination.formattedPrice,
                            style: AppTextStyles.cardPrice,
                          ),
                          Text('/p', style: AppTextStyles.cardPriceSuffix),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.destination});

  final DestinationModel destination;

  @override
  Widget build(BuildContext context) {
    if (destination.imageAsset != null) {
      return Image.asset(destination.imageAsset!, fit: BoxFit.cover);
    }
    return ColoredBox(color: destination.imagePlaceholderColor);
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isEco = label.toUpperCase() == 'ECO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isEco ? AppColors.ecoGreen500 : AppColors.tagGold600,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEco) ...[
            const Icon(Icons.eco, size: 8, color: AppColors.surface100),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AppTextStyles.tagPill.copyWith(
              fontSize: 8,
              color: isEco ? AppColors.surface100 : AppColors.neutral1100,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surface100,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.favorite_border,
          size: 10,
          color: AppColors.neutral800,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 12, color: AppColors.primary500),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: AppTextStyles.cardRating),
      ],
    );
  }
}
