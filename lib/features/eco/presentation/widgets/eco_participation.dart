import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/shared/widgets/app_confirm_dialog.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/face_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';

/// Unirse a una actividad ECO o salir de ella, con el mismo comportamiento y
/// los mismos avisos desde el detalle y desde la pantalla principal.
///
/// Cada método devuelve la actividad ya actualizada para que la pantalla se
/// ponga al día **sin recargar**, o `null` si no cambió nada. No finge nada
/// antes de que el servidor responda: el botón conserva su estado hasta
/// entonces.
///
/// Un solo aviso por acción: éxito, o el motivo por el que no se pudo.
///
/// El doble toque se bloquea en la pantalla (`_isJoining`), que es quien tiene
/// el botón; este helper no guarda estado.
abstract class EcoParticipation {
  /// "Unirme". [onRetry] es lo que hace el botón "Reintentar" de un fallo de
  /// red o de servidor: normalmente volver a llamar al mismo método.
  static Future<EcoActivityModel?> join(
    BuildContext context,
    EcoActivityModel activity, {
    required VoidCallback onRetry,
  }) async {
    // Un invitado no tiene a dónde inscribirse: se le guía a iniciar sesión
    // con la hoja de siempre, no con un error.
    if (!await GuestGuard.allow(context, GuestFeature.eco)) return null;
    if (!context.mounted) return null;
    if (!await FaceGuard.allow(context, FaceLimitedAction.ecoJoin)) return null;
    if (!context.mounted) return null;

    if (activity.isPast) {
      AppSnackbar.showInfo(context, 'Esta actividad ya finalizó.');
      return null;
    }
    if (activity.isJoinedByCurrentUser) {
      AppSnackbar.showInfo(context, 'Ya estás inscrito en esta actividad.');
      return null;
    }

    try {
      final updated = await EcoService().joinActivity(activity.id);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, '¡Te uniste a la actividad!');
      }
      return updated;
    } on EcoParticipationException catch (e) {
      if (context.mounted) _report(context, e, onRetry);
      return e.activity;
    }
  }

  /// "Abandonar actividad", siempre con confirmación. [confirmed] salta la
  /// pregunta cuando es un "Reintentar": ya se confirmó la primera vez.
  static Future<EcoActivityModel?> leave(
    BuildContext context,
    EcoActivityModel activity, {
    required VoidCallback onRetry,
    bool confirmed = false,
  }) async {
    if (!confirmed) {
      if (!await FaceGuard.allow(context, FaceLimitedAction.ecoJoin)) {
        return null;
      }
      if (!context.mounted) return null;
      final sure = await AppConfirmDialog.show(
        context,
        title: '¿Salir de la actividad?',
        message:
            'Dejarás de estar inscrito en "${activity.title}". Podrás volver '
            'a unirte si todavía hay cupo.',
        confirmLabel: 'Salir',
        cancelLabel: 'Cancelar',
      );
      if (!sure || !context.mounted) return null;
    }

    try {
      await EcoService().leaveActivity(activity.id);
      if (context.mounted) {
        AppSnackbar.showInfo(context, 'Saliste de la actividad');
      }
      return activity.withParticipation(
        isJoined: false,
        participantCount: math.max(0, activity.participantCount - 1),
      );
    } on EcoParticipationException catch (e) {
      if (context.mounted) _report(context, e, onRetry);
      return e.activity;
    }
  }

  /// Los fallos reales (red, tiempo, servidor) son un error con "Reintentar";
  /// llena, finalizada, ya inscrito o sin sesión se explican como información,
  /// porque no hay nada que reintentar ni nada que salió mal.
  static void _report(
    BuildContext context,
    EcoParticipationException e,
    VoidCallback onRetry,
  ) {
    if (e.canRetry) {
      AppSnackbar.showError(
        context,
        e.message,
        actionLabel: 'Reintentar',
        onAction: onRetry,
      );
    } else {
      AppSnackbar.showInfo(context, e.message);
    }
  }
}
