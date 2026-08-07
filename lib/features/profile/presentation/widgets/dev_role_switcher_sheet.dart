import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// "🧪 Cambiar Perfil (Dev Mode)" bottom sheet — lets a developer/QA jump
/// between [AuthService]'s two seed identities, or simulate the
/// client-to-owner "Partner" elevation in one tap, to preview both roles'
/// Profile experience without registering a real business.
class DevRoleSwitcherSheet extends StatelessWidget {
  const DevRoleSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      // Without this, the sheet caps itself at a fraction of the screen
      // height and refuses to grow, so on shorter screens the option cards
      // below the header get clipped into a RenderFlex overflow instead of
      // scrolling into view.
      isScrollControlled: true,
      backgroundColor: AppColors.settingsBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const DevRoleSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '🧪 Cambiar perfil (Dev Mode)',
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.settingsTextDark,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.profileDivider,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.settingsTextDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Solo para pruebas — no afecta tu cuenta real de Nikara.',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.settingsTextMuted,
              ),
            ),
            const SizedBox(height: 20),
            _DevRoleOption(
              emoji: '👤',
              title: 'Entrar como Sofía',
              subtitle: 'Cliente / Exploradora',
              onTap: () {
                AuthService().signInAs(kSofiaUserId);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 10),
            _DevRoleOption(
              emoji: '🏨',
              title: 'Entrar como Carlos',
              subtitle: 'Dueño de 2 negocios',
              onTap: () {
                AuthService().signInAs(kCarlosUserId);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 10),
            _DevRoleOption(
              emoji: '➕',
              title: 'Simular paso por Registro Web / Partner',
              subtitle: 'Convertir al usuario actual en dueño',
              onTap: () {
                AuthService().simulatePartnerRegistration();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DevRoleOption extends StatelessWidget {
  const _DevRoleOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.profileDivider,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.detailRowText.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.reviewMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.neutral500),
            ],
          ),
        ),
      ),
    );
  }
}
