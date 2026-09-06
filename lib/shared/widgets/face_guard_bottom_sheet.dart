import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/profile_face_service.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Las acciones que solo existen desde la cara de turista; define el copy de
/// [FaceLimitationSheet].
///
/// Todas tienen algo en común: son cosas que hace un **visitante**. Un negocio
/// no se guarda a sí mismo en favoritos, no se reseña, no se inscribe como
/// voluntario y no sale de viaje — la limitación no es un permiso que falte,
/// es que la acción no tiene sentido bajo esa identidad.
enum FaceLimitedAction {
  favoritos('guardar lugares en favoritos', Icons.favorite_border_rounded),
  resena('escribir reseñas', Icons.rate_review_outlined),
  ecoJoin('inscribirte en una jornada ECO', Icons.eco_outlined),
  viaje('iniciar un viaje', Icons.navigation_outlined);

  const FaceLimitedAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Gate de las acciones de visitante cuando hay una cara de negocio o fundación
/// puesta.
///
/// Se avisa en vez de esconder o deshabilitar controles: las 5 tabs siguen
/// visibles e iguales, y el aviso enseña el modelo mental —qué cara está
/// puesta, y que hay otra— en lugar de dejar botones muertos sin explicación.
class FaceGuard {
  const FaceGuard._();

  /// `true` si la acción puede seguir. Si no, muestra el aviso y devuelve
  /// `false`; si desde el aviso el usuario vuelve a turista, devuelve `true`
  /// para que la acción continúe sin pedirle un segundo toque.
  static Future<bool> allow(
    BuildContext context,
    FaceLimitedAction action,
  ) async {
    if (ProfileFaceService().canInteractAsVisitor) return true;
    final switched = await FaceLimitationSheet.show(context, action: action);
    return switched;
  }
}

class FaceLimitationSheet extends StatelessWidget {
  const FaceLimitationSheet({
    super.key,
    required this.action,
    required this.faceName,
  });

  final FaceLimitedAction action;

  /// Nombre de la cara puesta ahora mismo — decirlo es la mitad del mensaje:
  /// sin él, "cambiá a tu perfil de turista" no explica desde dónde.
  final String faceName;

  /// Devuelve `true` si el usuario volvió a la cara de turista desde el aviso.
  static Future<bool> show(
    BuildContext context, {
    required FaceLimitedAction action,
  }) async {
    final faceName = ProfileFaceService().activeFace?.name ?? 'tu negocio';
    final switched = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FaceLimitationSheet(action: action, faceName: faceName),
    );
    return switched ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.md,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary500.withValues(alpha: 0.16),
              ),
              child: Icon(
                action.icon,
                color: AppColors.settingsTextDark,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cambiá a tu perfil de turista',
              textAlign: TextAlign.center,
              style: AppTextStyles.registerHeading,
            ),
            const SizedBox(height: 8),
            Text(
              'Estás usando Níkara como $faceName. Para ${action.label} '
              'necesitás tu perfil de turista.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary500, AppColors.primary700],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () {
                      // Cambiar de cara no hace I/O: la acción que disparó el
                      // aviso puede continuar en el mismo toque.
                      ProfileFaceService().backToTurista();
                      Navigator.of(context).pop(true);
                    },
                    child: Center(
                      child: Text(
                        'Cambiar a turista',
                        style: AppTextStyles.buttonLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Seguir como $faceName', style: AppTextStyles.link),
            ),
          ],
        ),
      ),
    );
  }
}
