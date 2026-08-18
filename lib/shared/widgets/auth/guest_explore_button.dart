import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// "Explorar como invitado" pill CTA on Login — a muted-olive gradient
/// pill with a filled icon-circle, per the Claude Design canvas "Nikara
/// Inicio y Mapa" (turn 9, "Login v3"). A step up from a plain text
/// button: guest browsing is a first-class path here, not an
/// afterthought.
class GuestExploreButton extends StatelessWidget {
  const GuestExploreButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-1, -1),
            end: Alignment(1, 1),
            colors: [AppColors.authGuestPillStart, AppColors.authGuestPillEnd],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.authLink.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.authLink.withValues(alpha: 0.22),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.authLink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore,
                size: 14,
                color: AppColors.surface100,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                'Explorar como invitado',
                style: AppTextStyles.authGuestPillLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward,
              size: 16,
              color: AppColors.authLink,
            ),
          ],
        ),
      ),
    );
  }
}
