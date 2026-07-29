import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Renders an image picked via `image_picker` — a real filesystem path on
/// mobile/desktop, a `blob:` URL on web — falling back to a soft
/// placeholder whenever the path is missing, the file no longer exists on
/// disk, or loading fails for any other reason (e.g. a web session whose
/// blob URL expired after a refresh).
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
    if (!kIsWeb && !File(imagePath).existsSync()) return _fallback();

    return kIsWeb
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
      child: Icon(fallbackIcon, size: fallbackIconSize, color: AppColors.neutral500),
    );
  }
}
