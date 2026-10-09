import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';

/// Marca o quita el favorito [id] y avisa lo que corresponde, igual en todas
/// las pantallas (Inicio, Mapa, Perfil y detalle de negocio).
///
/// - **Marcar:** sin aviso; el corazón lleno ya es la respuesta.
/// - **Quitar con éxito:** `AppSnackbar.showInfo` "Quitado de favoritos" con
///   "Deshacer", que lo vuelve a marcar.
/// - **Fallo** (sin conexión, error del servidor): `AppSnackbar.showError` con
///   el mensaje del servicio, y el corazón se queda como estaba. No sale el
///   aviso de "quitado".
///
/// Devuelve el estado nuevo (`true` = favorito) o `null` si falló, para que
/// quien llama (el detalle de negocio) decida si actualiza algo propio.
/// [context] tiene que seguir montado mientras el aviso esté a la vista: si
/// la pantalla ya se cerró, el aviso simplemente no se muestra.
Future<bool?> toggleFavoriteWithFeedback(
  BuildContext context,
  String id,
) async {
  final ownerId = AuthService().currentAuthUser?.id;
  final bool nowFavorite;
  try {
    nowFavorite = await FavoritesService().toggleFavorite(id);
  } on FavoritesServiceException catch (e) {
    if (context.mounted) AppSnackbar.showError(context, e.message);
    return null;
  }
  if (!nowFavorite && context.mounted) {
    AppSnackbar.showInfo(
      context,
      'Quitado de favoritos',
      actionLabel: 'Deshacer',
      onAction: () => unawaited(_undoRemoval(context, id, ownerId)),
    );
  }
  return nowFavorite;
}

/// "Deshacer": vuelve a marcar [id]. Si falla, el corazón sigue como estaba
/// (quitado) y se avisa con el mensaje del servicio, ya en español.
Future<void> _undoRemoval(
  BuildContext context,
  String id,
  String? ownerId,
) async {
  if (ownerId == null || AuthService().currentAuthUser?.id != ownerId) return;
  final service = FavoritesService();
  // Si mientras tanto la persona ya lo volvió a marcar, no hay nada que
  // deshacer; alternar otra vez lo quitaría de nuevo.
  if (service.idsNotifier.value.contains(id)) return;
  try {
    await service.setFavorite(id, true);
  } on FavoritesServiceException catch (e) {
    if (context.mounted) AppSnackbar.showError(context, e.message);
  }
}
