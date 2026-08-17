import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/features/auth/presentation/screens/register_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// A restricted action a guest just tried to reach — drives the copy in
/// [GuestGuardBottomSheet].
enum GuestFeature {
  favoritos('tus favoritos', Icons.favorite_border),
  perfil('tu perfil', Icons.person_outline),
  eco('actividades ECO', Icons.eco_outlined);

  const GuestFeature(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Gate for anything that requires a real account — favorites, the Perfil
/// tab. A guest ([AuthService.isLoggedIn] false while inside the
/// app) never gets silently blocked; [allow] always explains why via
/// [GuestGuardBottomSheet] and points at how to unlock it.
class GuestGuard {
  const GuestGuard._();

  /// Returns true and does nothing if the user already has a real account.
  /// Otherwise shows [GuestGuardBottomSheet] and returns false — callers
  /// should just stop, there's no seamless "continue after login" here.
  static Future<bool> allow(BuildContext context, GuestFeature feature) async {
    if (AuthService().isLoggedIn) return true;
    await GuestGuardBottomSheet.show(context, feature: feature);
    return false;
  }
}

/// "Crea tu cuenta en 10 segundos para desbloquear esta función" — the
/// dynamic bottom sheet [GuestGuard.allow] shows when a guest reaches a
/// restricted action.
class GuestGuardBottomSheet extends StatelessWidget {
  const GuestGuardBottomSheet({super.key, required this.feature});

  final GuestFeature feature;

  static Future<void> show(
    BuildContext context, {
    required GuestFeature feature,
  }) {
    return showModalBottomSheet(
      context: context,
      // Not the default (false): a non-scroll-controlled sheet caps at
      // 9/16 of the screen height, which this sheet's content — icon,
      // heading, body copy, two buttons — is tall enough to exceed on a
      // shorter phone.
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => GuestGuardBottomSheet(feature: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.wizardFocus.withValues(alpha: 0.12),
              ),
              child: Icon(feature.icon, color: AppColors.wizardFocus, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Crea tu cuenta en 10 segundos',
              textAlign: TextAlign.center,
              style: AppTextStyles.registerHeading,
            ),
            const SizedBox(height: 8),
            Text(
              'Para desbloquear ${feature.label} necesitas una cuenta — '
              'es rápido y gratis.',
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Center(
                      child: Text(
                        'Crear mi cuenta',
                        style: AppTextStyles.buttonLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: Text('Ya tengo cuenta', style: AppTextStyles.link),
            ),
          ],
        ),
      ),
    );
  }
}
