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
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconSize = 28,
  });

  final String? path;
  final BoxFit fit;
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
            errorBuilder: (context, error, stackTrace) => _fallback(),
          )
        : Image.file(
            File(imagePath),
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _fallback(),
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
