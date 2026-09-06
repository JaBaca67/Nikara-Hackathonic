import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// La cabecera del perfil, compartida por todas las caras.
///
/// Es la "plantilla" a la que se refiere el sistema de caras: la cara de
/// turista y la de un negocio o fundación se leen como la misma pantalla con
/// distinto contenido, no como dos pantallas con ideas distintas. Todo lo que
/// varía entra por parámetro —qué acciones hay arriba, qué imagen, qué dice el
/// selector, qué tres números— y la estructura no se duplica en ningún lado.
class ProfileHeaderShell extends StatelessWidget {
  const ProfileHeaderShell({
    super.key,
    required this.actions,
    required this.avatar,
    required this.faceControl,
    required this.stats,
  });

  /// Botones circulares de la fila del título; ver [ProfileHeaderIconButton].
  final List<Widget> actions;

  final Widget avatar;

  /// El control de cambio de cara — [FaceSelectorControl].
  final Widget faceControl;

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Perfil', style: AppTextStyles.profileScreenTitle),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(child: faceControl),
              ],
            ),
          ),
          ProfileStatsRow(stats: stats),
        ],
      ),
    );
  }
}

class ProfileHeaderIconButton extends StatelessWidget {
  const ProfileHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Descripción para lectores de pantalla — el botón no tiene texto visible.
  /// Es obligatorio a propósito: así el compilador obliga a etiquetar
  /// cualquier uso nuevo.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.profileDivider,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.settingsTextDark),
        ),
      ),
    );
  }
}

/// Control **provisional** para cambiar de cara: el nombre de la cara activa
/// con un chevron al lado.
///
/// Se eligió un control explícito y no el avatar porque el avatar ya sirve para
/// cambiar la imagen: colgarle un segundo significado lo volvería ambiguo justo
/// en el gesto más usado de la pantalla. Se decidió sin prototipo de Claude
/// Design para que la interacción exista y se pueda probar; el pulido visual
/// viene después.
class FaceSelectorControl extends StatelessWidget {
  const FaceSelectorControl({
    super.key,
    required this.name,
    required this.kindLabel,
    required this.onTap,
  });

  final String name;

  /// "Turista" / "Negocio" / "Fundación"; nula mientras las caras cargan.
  final String? kindLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = kindLabel;
    return Semantics(
      button: true,
      label: 'Cambiar de perfil. Perfil activo: $name',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: AppTextStyles.profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: AppColors.settingsTextDark,
                  ),
                ],
              ),
              if (label != null)
                Text(
                  label,
                  style: AppTextStyles.settingsRowCaption.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El círculo de la cabecera: foto de perfil del turista, o logo/portada de la
/// cara de negocio o fundación.
class ProfileFaceAvatar extends StatelessWidget {
  const ProfileFaceAvatar({
    super.key,
    required this.imageUrl,
    required this.initials,
    required this.label,
    this.isSaving = false,
    this.fallbackIcon,
    this.onTap,
  });

  /// URL o ruta local de la imagen; nula = [initials].
  final String? imageUrl;

  final String initials;

  /// Qué hace el toque, para lectores de pantalla ("Cambiar foto de perfil",
  /// "Editar la imagen del negocio").
  final String label;

  /// Subida en curso: se tapa la foto con un spinner y se ignoran los toques.
  final bool isSaving;

  /// Reemplaza a [initials] cuando el tipo de cara tiene un ícono más claro que
  /// dos letras (una fundación sin logo, por ejemplo).
  final IconData? fallbackIcon;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final path = imageUrl;
    final hasPhoto = path != null && path.isNotEmpty;
    final icon = fallbackIcon;

    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: isSaving ? null : onTap,
        child: Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.settingsAccent, AppColors.destructive],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.settingsAccent.withValues(alpha: 0.35),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(1.6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.surface100, width: 1.6),
              ),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPhoto)
                    LocalImage(path: path)
                  else
                    Container(
                      color: AppColors.profileDivider,
                      alignment: Alignment.center,
                      child: icon == null
                          ? Text(
                              initials,
                              style: AppTextStyles.h5.copyWith(
                                color: AppColors.settingsTextDark,
                              ),
                            )
                          : Icon(
                              icon,
                              size: 30,
                              color: AppColors.settingsTextDark,
                            ),
                    ),
                  if (isSaving)
                    Container(
                      color: AppColors.detailCoverCounterBg,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.surface100,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una columna de la fila de estadísticas de la cabecera.
///
/// [icon] y [tint] son opcionales porque la cara de turista no los usa: sus
/// tres números (viajes, insignias, puntos) son de la misma naturaleza y un
/// color por columna no diría nada. Ver `FaceProfileScreen` para el caso en que
/// sí dicen algo.
class ProfileStat {
  const ProfileStat({
    required this.value,
    required this.label,
    this.icon,
    this.tint,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? tint;
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.profileDivider, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++)
            Expanded(
              child: _StatColumn(
                stat: stats[i],
                showDivider: i < stats.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.stat, required this.showDivider});

  final ProfileStat stat;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final icon = stat.icon;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.profileDivider, width: 0.8),
              ),
            )
          : null,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: stat.tint ?? AppColors.settingsTextMuted,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  stat.value,
                  style: AppTextStyles.profileStatValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: AppTextStyles.profileStatLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
