import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Cabecera de perfil público, compartida por `OrganizationProfileScreen` y `PublicUserProfileScreen` para que ambos se lean como la misma pantalla con distinto contenido.
class PublicProfileHeader extends StatelessWidget {
  const PublicProfileHeader({
    super.key,
    required this.name,
    required this.avatar,
    required this.accent,
    required this.onBack,
    this.bannerPath,
    this.handle,
    this.contextLine,
    this.badgeIcon,
    this.badgeLabel,
    this.verified = false,
    this.action,
  });

  final String name;

  final Widget avatar;

  /// Olivo para fundaciones, dorado para personas.
  final Color accent;

  final VoidCallback onBack;
  final String? bannerPath;
  final String? handle;

  final String? contextLine;

  final IconData? badgeIcon;
  final String? badgeLabel;
  final bool verified;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final handle = this.handle;
    final contextLine = this.contextLine;
    final badgeLabel = this.badgeLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: 44,
                child: LocalImage(
                  path: bannerPath,
                  fallbackIcon: Icons.image_outlined,
                  fallbackIconSize: 0,
                ),
              ),
              Positioned(
                left: 16,
                top: 8,
                child: SafeArea(
                  bottom: false,
                  child: _CircleButton(icon: Icons.arrow_back, onTap: onBack),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 0,
                child: _AvatarWithBadge(
                  avatar: avatar,
                  accent: accent,
                  badgeIcon: badgeIcon,
                ),
              ),
              if (action != null)
                Positioned(right: 20, bottom: 10, child: action!),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: AppTextStyles.detailTitle.copyWith(fontSize: 21),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified_rounded, size: 18, color: accent),
                  ],
                ],
              ),
              if (handle != null && handle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  handle,
                  style: AppTextStyles.settingsSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (contextLine != null && contextLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 14,
                      color: AppColors.settingsTextMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        contextLine,
                        style: AppTextStyles.settingsSubtitle.copyWith(
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (badgeLabel != null && badgeLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                _CredentialPill(
                  icon: badgeIcon ?? Icons.verified_rounded,
                  label: badgeLabel,
                  accent: accent,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({
    required this.avatar,
    required this.accent,
    required this.badgeIcon,
  });

  final Widget avatar;
  final Color accent;
  final IconData? badgeIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface100,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.mapControlShadowSoft,
                  offset: Offset(0, 4),
                  blurRadius: 14,
                ),
              ],
            ),
            // El recorte va dentro del padding y no sobre el borde: así el
            // marco blanco es un anillo parejo y la foto llena su cuadrado,
            // en vez de dejar franjas cuando no es cuadrada.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: SizedBox.expand(child: avatar),
            ),
          ),
          if (badgeIcon != null)
            Positioned(
              right: 0,
              bottom: 8,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface100, width: 2),
                ),
                child: Icon(badgeIcon, size: 13, color: AppColors.surface100),
              ),
            ),
        ],
      ),
    );
  }
}

class _CredentialPill extends StatelessWidget {
  const _CredentialPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 11.5,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface100.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.settingsTextDark),
      ),
    );
  }
}

/// Fila de estadísticas del perfil, valor arriba y etiqueta abajo.
class PublicProfileStats extends StatelessWidget {
  const PublicProfileStats({super.key, required this.items});

  final List<({String value, String label})> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0)
              Container(width: 1, height: 32, color: AppColors.profileDivider),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.settingsTextDark,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.quickInfoLabel,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
