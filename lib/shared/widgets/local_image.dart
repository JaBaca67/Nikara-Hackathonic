import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Renderiza una imagen de `image_picker` (path real en mobile/desktop, `blob:` en web) o una URL http(s), con fallback si falta/falla la carga.
class LocalImage extends StatelessWidget {
  const LocalImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconSize = 28,
  });

  final String? path;
  final BoxFit fit;

  /// Qué parte se conserva al recortar con [BoxFit.cover]. Las fotos de perfil
  /// usan un encuadre más alto que el centro, donde suele estar la cara.
  final Alignment alignment;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final imagePath = path;
    if (imagePath == null || imagePath.isEmpty) return _fallback();
    final isRemote =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');
    if (!kIsWeb && !isRemote && !File(imagePath).existsSync()) {
      return _fallback();
    }

    return kIsWeb || isRemote
        ? Image.network(
            imagePath,
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            alignment: alignment,
            // `frameBuilder`, no `loadingBuilder`: este último solo reacciona
            // a los bytes de descarga, así que en una imagen ya en la caché
            // HTTP o que llega completa en un solo chunk nunca pasa por
            // "cargando" — hay un frame en blanco entre que el `Image` se
            // monta y el primer frame decodificado se pinta. `frameBuilder`
            // cubre ese hueco porque se dispara según frames decodificados,
            // no bytes de red. Encontrado al reemplazar el logo de una
            // fundación ya publicada: el círculo se veía blanco un instante
            // justo después de guardar, como si no hubiera guardado nada.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                wasSynchronouslyLoaded || frame != null
                ? child
                : _placeholder(),
            errorBuilder: (context, error, stackTrace) => _fallback(),
          )
        : Image.file(
            File(imagePath),
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            alignment: alignment,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.placeholderTan,
    );
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.placeholderTan,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: fallbackIconSize,
        color: AppColors.neutral500,
      ),
    );
  }
}
