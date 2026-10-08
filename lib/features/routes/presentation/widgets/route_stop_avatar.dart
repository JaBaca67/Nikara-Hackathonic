import 'package:flutter/material.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Identidad visual de una parada: foto/logo del lugar y un icono reconocible
/// cuando el catálogo todavía no tiene imagen.
class RouteStopAvatar extends StatelessWidget {
  const RouteStopAvatar({super.key, required this.stop, this.size = 48});

  final RouteStopModel stop;
  final double size;

  IconData get _fallbackIcon {
    if (stop.kind == RouteStopKind.ecoActivity) return Icons.eco_rounded;
    if (stop.category == RouteStopCategory.gastronomico) {
      return Icons.restaurant_rounded;
    }
    return stop.kind == RouteStopKind.business
        ? Icons.storefront_rounded
        : Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .32),
    child: SizedBox.square(
      dimension: size,
      child: LocalImage(
        path: stop.imagePath,
        fallbackIcon: _fallbackIcon,
        fallbackIconSize: size * .48,
      ),
    ),
  );
}
