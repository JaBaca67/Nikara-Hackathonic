import 'package:flutter/material.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/theme/app_theme.dart';

class OriginBadge extends StatelessWidget {
  const OriginBadge({super.key, required this.origin});
  final UserOrigin origin;

  @override
  Widget build(BuildContext context) {
    if (!origin.hasCountry) return const SizedBox.shrink();
    return Semantics(
      label: 'Procedencia: ${origin.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/flags/${origin.countryCode!.toLowerCase()}.png',
              width: 24,
              height: 18,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                origin.label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
