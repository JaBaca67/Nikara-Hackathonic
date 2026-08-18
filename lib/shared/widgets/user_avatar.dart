import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Foto de perfil recortada a un cuadrado perfecto, con las iniciales como
/// respaldo.
///
/// Centraliza el encuadre porque una foto de perfil casi nunca es cuadrada:
/// sin `BoxFit.cover` sobre una caja de lado fijo, una imagen apaisada o
/// vertical deja franjas del fondo a los lados. El recorte se alinea hacia
/// arriba, que es donde suele estar la cara.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    this.size,
    this.borderRadius,
    this.background = AppColors.primario1,
    this.foreground = AppColors.primario7,
    this.initialsStyle,
  });

  final String? avatarUrl;
  final String initials;

  /// Null = ocupa lo que le dé el padre (para un `SizedBox`/`Container` que ya
  /// fija la caja, como la cabecera del perfil público).
  final double? size;

  /// Null = círculo.
  final BorderRadius? borderRadius;

  final Color background;
  final Color foreground;
  final TextStyle? initialsStyle;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final radius = borderRadius;

    final content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? LocalImage(
              path: url,
              alignment: const Alignment(0, -0.25),
              fallbackIcon: Icons.person_rounded,
            )
          : Center(
              child: Text(
                initials,
                style:
                    initialsStyle ??
                    AppTextStyles.sectionTitle.copyWith(
                      fontSize: size == null ? 20 : size! * 0.36,
                      color: foreground,
                    ),
              ),
            ),
    );

    return content;
  }
}
