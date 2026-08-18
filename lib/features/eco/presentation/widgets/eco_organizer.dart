import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/public_user_profile_screen.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Sin perfil real que mostrar en jornadas sembradas por el seed (sin fundación ni `organizer_id`): no hace nada.
Future<void> openEcoOrganizerProfile(
  BuildContext context,
  EcoActivityModel activity,
) async {
  final organizationId = activity.organizationId;
  if (activity.isFromOrganization && organizationId != null) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OrganizationProfileScreen(organizationId: organizationId),
      ),
    );
    return;
  }
  final organizerId = activity.organizerId;
  if (organizerId == null || organizerId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta actividad no tiene un perfil de organizador.'),
      ),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublicUserProfileScreen(
        userId: organizerId,
        fallbackName: activity.organizerDisplayName,
      ),
    ),
  );
}

class EcoOrganizerAvatar extends StatelessWidget {
  const EcoOrganizerAvatar({
    super.key,
    required this.activity,
    this.size = 40,
    this.borderRadius,
  });

  final EcoActivityModel activity;
  final double size;

  /// Redondeado completo por defecto (circular); el perfil pasa esquinas suaves en su lugar.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final logo = activity.organizationLogoUrl;
    final radius = borderRadius ?? BorderRadius.circular(size);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: logo != null && logo.isNotEmpty
            ? LocalImage(path: logo, fallbackIcon: Icons.eco_rounded)
            : Container(
                color: activity.isFromOrganization
                    ? AppColors.detailActivityIconBg
                    : AppColors.ecoGreen500.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Text(
                  activity.organizerInitials,
                  style: AppTextStyles.mapRowTitle.copyWith(
                    fontSize: size * 0.34,
                    color: AppColors.ecoActive,
                  ),
                ),
              ),
      ),
    );
  }
}

class EcoOrganizerRow extends StatelessWidget {
  const EcoOrganizerRow({super.key, required this.activity, this.onTap});

  final EcoActivityModel activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          EcoOrganizerAvatar(activity: activity, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              activity.organizerDisplayName,
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 11.5,
                color: AppColors.settingsTextMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (activity.organizerIsVerified) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.verified_rounded,
              size: 13,
              color: AppColors.ecoActive,
            ),
          ],
        ],
      ),
    );
  }
}
