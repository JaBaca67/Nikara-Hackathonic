import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Renders an image picked via `image_picker` — a real filesystem path on
/// mobile/desktop, a `blob:` URL on web — falling back to a soft
/// placeholder whenever the path is missing, the file no longer exists on
/// disk, or loading fails for any other reason (e.g. a web session whose
/// blob URL expired after a refresh).
///
/// También acepta una URL `http(s)` y la carga por red en cualquier
/// plataforma: los campos `logo_url`/`banner_url` de una fundación admiten
/// tanto una imagen del dispositivo como una URL pegada a mano.
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
