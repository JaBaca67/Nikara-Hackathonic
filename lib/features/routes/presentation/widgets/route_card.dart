import 'package:flutter/material.dart';

import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/profile/presentation/screens/public_user_profile_screen.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/user_avatar.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Tarjeta de una ruta en `RoutesMainScreen` — collage de fotos de portada
/// (o, en su falta, prestadas de las paradas), título, días/paradas y los
/// chips de categoría del itinerario.
///
/// En la pestaña Comunidad ([showCreator]/[onCopy]) agrega arriba una
/// cabecera con quién la publicó y un botón rápido "Copiar ruta" que no
/// pasa por el detalle — para que copiar una ruta ajena sea un solo tap.
class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.onTap,
    this.showCreator = false,
    this.onCopy,
  });

  final RouteModel route;
  final VoidCallback onTap;
  final bool showCreator;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadowSoft,
              offset: Offset(0, 6),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCreator) ...[
              _CreatorHeader(route: route, onCopy: onCopy),
              const SizedBox(height: 12),
            ],
            RoutePhotoCollage(images: route.coverImages()),
            const SizedBox(height: 14),
            Text(
              route.title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.settingsTextDark,
                fontSize: 17,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: _MetaItem(
                    icon: Icons.calendar_month_rounded,
                    label: '${route.days} ${route.days == 1 ? 'día' : 'días'}',
                  ),
                ),
                const SizedBox(width: 18),
                Flexible(
                  child: _MetaItem(
                    icon: Icons.place_rounded,
                    label:
                        '${route.stopCount} '
                        '${route.stopCount == 1 ? 'parada' : 'paradas'}',
                  ),
                ),
              ],
            ),
            if (route.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in route.categories)
                    RouteCategoryChip(category: category),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cabecera "de {creador}" de una tarjeta de la pestaña Comunidad: foto real
/// del creador, su nombre —ambos enlazan a su perfil público— y el botón
/// rápido "Copiar ruta".
class _CreatorHeader extends StatelessWidget {
  const _CreatorHeader({required this.route, required this.onCopy});

  final RouteModel route;
  final VoidCallback? onCopy;

  void _openCreator(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicUserProfileScreen(
          userId: route.ownerId,
          fallbackName: route.creatorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // GestureDetector propio, igual que el de "Copiar ruta": abrir el
        // perfil del creador no debe abrir además el detalle de la ruta.
        GestureDetector(
          onTap: route.ownerId.isEmpty ? null : () => _openCreator(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                avatarUrl: route.creatorAvatarUrl,
                initials: route.creatorInitials,
                size: 32,
                background: AppColors.warmChipBackground,
                foreground: AppColors.settingsTextDark,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: route.ownerId.isEmpty ? null : () => _openCreator(context),
            child: Text(
              route.creatorDisplayName,
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 13,
                color: AppColors.settingsTextMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          // GestureDetector aparte del de la tarjeta entera: al tocarlo, el
          // reconocedor de este botón gana la arena de gestos para ese
          // toque y el tap nunca llega al de la tarjeta — "Copiar ruta"
          // nunca abre el detalle de paso.
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.settingsBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: AppColors.settingsTextDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Copiar ruta',
                    style: AppTextStyles.mapRowTitle.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Collage de la tarjeta: una foto grande a la izquierda y dos apiladas a
/// la derecha. Los huecos que no tienen foto se rellenan con el placeholder
/// de [LocalImage] — nunca se repite una imagen para simular más contenido
/// del que la ruta tiene.
class RoutePhotoCollage extends StatelessWidget {
  const RoutePhotoCollage({super.key, required this.images, this.height = 190});

  final List<String> images;
  final double height;

  String? _imageAt(int index) => index < images.length ? images[index] : null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            flex: 55,
            child: _CollageTile(path: _imageAt(0), height: height),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 45,
            child: Column(
              children: [
                Expanded(child: _CollageTile(path: _imageAt(1))),
                const SizedBox(height: 8),
                Expanded(child: _CollageTile(path: _imageAt(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollageTile extends StatelessWidget {
  const _CollageTile({required this.path, this.height});

  final String? path;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LocalImage(
          path: path,
          fallbackIcon: Icons.photo_outlined,
          fallbackIconSize: 0,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.settingsTextMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Chip "Turístico" / "ECO" / "Gastronómico". [compact] es la versión en
/// versalitas que usan el paso 2 del wizard y el timeline del detalle.
class RouteCategoryChip extends StatelessWidget {
  const RouteCategoryChip({
    super.key,
    required this.category,
    this.compact = false,
  });

  final RouteStopCategory category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isEco = category == RouteStopCategory.eco;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: isEco
            ? AppColors.detailActivityIconBg
            : AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact ? category.label.toUpperCase() : category.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.mapRowTitle.copyWith(
          fontSize: compact ? 9.5 : 12,
          letterSpacing: compact ? 0.3 : 0,
          color: isEco ? AppColors.ecoActive : AppColors.settingsTextDark,
        ),
      ),
    );
  }
}
