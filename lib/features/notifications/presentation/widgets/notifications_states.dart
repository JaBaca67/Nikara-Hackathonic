import 'package:flutter/material.dart';

import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/features/auth/presentation/screens/register_screen.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Estructura compartida de los estados sin lista (vacío, invitado, error):
/// ilustración circular + título + explicación + CTA. Es el mismo patrón que
/// ya usan Rutas (`_RoutesEmptyState`) y Favoritos (`_FavoritesEmptyState`);
/// se replica acá en vez de inventar uno nuevo.
class _NotificationsPlaceholder extends StatelessWidget {
  const _NotificationsPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          Container(
            width: 148,
            height: 148,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.warmChipBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: AppColors.primary500),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.settingsTextDark,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.settingsSubtitle.copyWith(
              color: AppColors.settingsTextMuted,
              fontSize: 14,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.settingsTextDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.lg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 15),
              ),
              child: Text(actionLabel!),
            ),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: AppTextStyles.link.copyWith(color: AppColors.oliveText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bandeja al día: no hay ninguna notificación para el usuario.
class NotificationsEmptyState extends StatelessWidget {
  const NotificationsEmptyState({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return _NotificationsPlaceholder(
      icon: Icons.notifications_none_rounded,
      title: 'No tienes notificaciones',
      message:
          'Aquí te avisamos cuando aprobamos tu negocio, cuando alguien se '
          'suma a tu jornada ECO y cuando se acerca una actividad que '
          'reservaste.',
      actionLabel: 'Seguir explorando',
      onAction: onExplore,
    );
  }
}

/// Un invitado no tiene fila propia en `notifications`, así que no se le
/// muestra una bandeja vacía —que sugeriría que "no pasó nada"— sino la
/// razón real. Las acciones son las mismas que ofrece
/// `GuestGuardBottomSheet`: crear cuenta o iniciar sesión.
class NotificationsGuestState extends StatelessWidget {
  const NotificationsGuestState({super.key});

  @override
  Widget build(BuildContext context) {
    return _NotificationsPlaceholder(
      icon: Icons.lock_outline_rounded,
      title: 'Crea tu cuenta para recibir avisos',
      message:
          'Las notificaciones son personales: necesitas una cuenta para que '
          'podamos avisarte sobre tus negocios y tus jornadas ECO.',
      actionLabel: 'Crear mi cuenta',
      onAction: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
      secondaryLabel: 'Ya tengo cuenta',
      onSecondary: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
    );
  }
}

class NotificationsErrorState extends StatelessWidget {
  const NotificationsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _NotificationsPlaceholder(
      icon: Icons.cloud_off_rounded,
      title: 'No pudimos cargar tus notificaciones',
      message: message,
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}

/// Esqueleto con la forma real de las filas mientras carga la consulta —
/// preferido al spinner centrado porque no desplaza el layout cuando llegan
/// los datos. Deliberadamente **sin animación**: un shimmer infinito rompe
/// `pumpAndSettle()` en los tests de widget, igual que `AuroraBackgroundWidget`.
class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => const _SkeletonRow(),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBlock(width: 40, height: 40, circle: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBlock(width: 160, height: 12),
                const SizedBox(height: AppSpacing.sm),
                const _SkeletonBlock(width: double.infinity, height: 10),
                const SizedBox(height: AppSpacing.sm),
                const _SkeletonBlock(width: 210, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.circle = false,
  });

  final double width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.profileDivider,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(AppRadius.xs),
      ),
    );
  }
}
