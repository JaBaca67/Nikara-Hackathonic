import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Bloques visuales compartidos por las pantallas de detalle (`BusinessDetailScreen`, `EcoDetailScreen`), que antes duplicaban la misma jerarquía con widgets privados (Pantalla 3a de Figma sigue siendo la fuente de verdad de medidas/colores).

/// Portada con [PageView] de fotos, degradados, botones flotantes y contador "1 / N".
class DetailCoverImage extends StatefulWidget {
  const DetailCoverImage({
    super.key,
    required this.photos,
    required this.height,
    required this.onBack,
    required this.caption,
    this.actions = const [],
    this.fallbackIcon = Icons.image_outlined,
  });

  final List<String> photos;
  final double height;
  final VoidCallback onBack;
  final Widget caption;

  final List<Widget> actions;

  final IconData fallbackIcon;

  @override
  State<DetailCoverImage> createState() => _DetailCoverImageState();
}

class _DetailCoverImageState extends State<DetailCoverImage> {
  final _pageController = PageController();
  int _photoIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photos.isEmpty
              ? LocalImage(
                  path: null,
                  fallbackIcon: widget.fallbackIcon,
                  fallbackIconSize: 48,
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: photos.length,
                  onPageChanged: (index) => setState(() => _photoIndex = index),
                  itemBuilder: (context, index) => LocalImage(
                    path: photos[index],
                    fallbackIcon: widget.fallbackIcon,
                    fallbackIconSize: 48,
                  ),
                ),
          // Un Container decorado hace hit-test opaco en todo su rectángulo; sin IgnorePointer se comía el arrastre del PageView.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.detailCoverScrimTop,
                    AppColors.detailCoverScrimClear,
                  ],
                  stops: [0.0, 0.32],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.detailCoverScrimBottom,
                    AppColors.detailCoverScrimClear,
                  ],
                  stops: [0.0, 0.6],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DetailCoverIconButton(
                        icon: Icons.arrow_back,
                        onTap: widget.onBack,
                      ),
                      Row(children: widget.actions),
                    ],
                  ),
                  const Spacer(),
                  IgnorePointer(child: widget.caption),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              right: 16,
              bottom: 88,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.detailCoverCounterBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.detailCoverCounterBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library,
                        size: 13,
                        color: AppColors.surface100,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_photoIndex + 1} / ${photos.length}',
                        style: AppTextStyles.detailTagPill.copyWith(
                          color: AppColors.surface100,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón circular esmerilado (volver/compartir/favorito) de la portada.
class DetailCoverIconButton extends StatelessWidget {
  const DetailCoverIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface100.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surface100.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(icon, size: 19, color: AppColors.surface100),
          ),
        ),
      ),
    );
  }
}

/// Pill de categoría sobre la portada.
class DetailCoverTagPill extends StatelessWidget {
  const DetailCoverTagPill({
    super.key,
    required this.label,
    this.background = AppColors.tagGold600,
    this.foreground = AppColors.settingsTextDark,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.detailTagPill.copyWith(color: foreground),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Tarjeta flotante de datos rápidos, montada medio superpuesta a la portada.
class DetailQuickInfoCard extends StatelessWidget {
  const DetailQuickInfoCard({super.key, required this.items});

  final List<DetailQuickInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mapControlBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapControlShadowSoft,
            offset: Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0)
              Container(width: 1, height: 32, color: AppColors.profileDivider),
            Expanded(child: items[i]),
          ],
        ],
      ),
    );
  }
}

class DetailQuickInfoItem extends StatelessWidget {
  const DetailQuickInfoItem({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.quickInfoLabel,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.quickInfoValue.copyWith(
            color: valueColor ?? AppColors.settingsTextDark,
          ),
        ),
      ],
    );
  }
}

/// Selector de pestañas de las pantallas de detalle.
class DetailSegmentedTabs extends StatelessWidget {
  const DetailSegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentedTrackBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _SegmentButton(
                label: labels[i],
                selected: selected == i,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.detailSegmentGlow,
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.segmentedTabLabel.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: selected
                ? AppColors.settingsTextDark
                : AppColors.settingsTextMuted,
          ),
        ),
      ),
    );
  }
}

/// Título de sección + contenido, con el espaciado de Pantalla 3a.
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.detailSectionTitle),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Fila con chip de ícono + etiqueta; compartida entre "Actividades" del negocio y "Requisitos y qué llevar" de ECO.
class DetailIconRow extends StatelessWidget {
  const DetailIconRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppColors.settingsTextMuted,
    this.iconBackground = AppColors.settingsBackground,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackground;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.detailActivityLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Tarjeta de perfil compartida entre "Anfitrión" del negocio y "Organizador" de ECO; [accent] cambia el dorado por el olivo del módulo ECO.
class DetailProfileCard extends StatelessWidget {
  const DetailProfileCard({
    super.key,
    required this.avatar,
    required this.name,
    this.caption,
    this.captionColor,
    this.verified = false,
    this.accent = AppColors.accent300,
    this.accentBackground = AppColors.detailActivityIconBg,
    this.onTap,
  });

  final Widget avatar;
  final String name;
  final String? caption;
  final Color? captionColor;
  final bool verified;
  final Color accent;
  final Color accentBackground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mapControlBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.detailCardGlow,
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(child: SizedBox(width: 48, height: 48, child: avatar)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.detailHostName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 11,
                              color: accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'VERIFICADO',
                              style: AppTextStyles.detailVerifiedBadge.copyWith(
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      color: captionColor ?? AppColors.settingsTextMuted,
                      fontWeight: captionColor == null ? null : FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.neutral400),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// "Cómo llegar": ilustración decorativa de mini-mapa (no un mapa real), dirección y pastilla que salta al mapa de Níkara.
class DetailMapCard extends StatelessWidget {
  const DetailMapCard({
    super.key,
    required this.address,
    required this.caption,
    required this.onTap,
    this.actionLabel = 'Abrir mapa',
    this.pinColor = AppColors.primary500,
    this.pinIconColor = AppColors.settingsTextDark,
  });

  final String address;
  final String caption;
  final VoidCallback onTap;
  final String actionLabel;
  final Color pinColor;
  final Color pinIconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.mapControlBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              child: _MiniMapIllustration(
                pinColor: pinColor,
                pinIconColor: pinIconColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address,
                          style: AppTextStyles.detailMapAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          caption,
                          style: AppTextStyles.profileCaption10.copyWith(
                            fontSize: 10.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.settingsBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      actionLabel,
                      style: AppTextStyles.detailPillAction,
                    ),
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

class _MiniMapIllustration extends StatelessWidget {
  const _MiniMapIllustration({
    required this.pinColor,
    required this.pinIconColor,
  });

  final Color pinColor;
  final Color pinIconColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.detailMapBg),
        Positioned(
          left: -20,
          right: -20,
          top: 38,
          child: Transform.rotate(
            angle: -7 * math.pi / 180,
            child: Container(height: 12, color: AppColors.detailMapRoad),
          ),
        ),
        Positioned(
          left: 60,
          top: -20,
          bottom: -20,
          width: 9,
          child: Transform.rotate(
            angle: 11 * math.pi / 180,
            child: Container(color: AppColors.detailMapRoad),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          child: ColoredBox(color: AppColors.detailMapGreen),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 27,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pinColor,
                shape: BoxShape.circle,
                border: const Border.fromBorderSide(
                  BorderSide(color: AppColors.surface100, width: 3),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.detailMapPinShadow,
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(Icons.location_on, size: 18, color: pinIconColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de acción inferior fija; el contenido lo pone cada pantalla.
class DetailBottomBar extends StatelessWidget {
  const DetailBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: const BoxDecoration(
          color: AppColors.surface100,
          border: Border(top: BorderSide(color: AppColors.mapControlBorder)),
          boxShadow: [
            BoxShadow(
              color: AppColors.detailBottomBarShadow,
              offset: Offset(0, -6),
              blurRadius: 22,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
