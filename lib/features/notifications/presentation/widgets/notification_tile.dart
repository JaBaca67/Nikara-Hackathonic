import 'package:flutter/material.dart';

import 'package:nikara_app/features/notifications/domain/models/app_notification.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Fila de una notificación en el listado (pantalla Notificaciones, tier
/// Funcional).
///
/// La distinción leída/no leída no se apoya en un solo indicador: la no leída
/// suma borde dorado, título en negrita, punto dorado y chip de ícono teñido;
/// la leída queda con borde neutro y peso normal. Tres de esas cuatro señales
/// no son de color, así que la fila se sigue distinguiendo con daltonismo.
///
/// Las dos variantes comparten fondo [AppColors.surface100] a propósito: con
/// la leída sobre [AppColors.profileDivider] el cuerpo en
/// [AppColors.settingsTextMuted] caía a 3.5:1 de contraste, peor que el 4.1:1
/// que ese par ya tiene en el resto de la app.
class NotificationTile extends StatefulWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.now,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// Reloj inyectable — solo para que los tests fijen el tiempo relativo.
  final DateTime? now;

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  void didUpdateWidget(covariant NotificationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notification.id != widget.notification.id) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final unread = !notification.isRead;
    final relative = notification.relativeTime(now: widget.now);
    final createdAt = notification.createdAt.toLocal();
    String padded(int value) => value.toString().padLeft(2, '0');
    final date =
        '${padded(createdAt.day)}/${padded(createdAt.month)}/'
        '${createdAt.year} · ${padded(createdAt.hour)}:${padded(createdAt.minute)}';

    return Semantics(
      button: true,
      onLongPress: _toggleExpanded,
      hint: _expanded
          ? 'Mantén presionado para contraer el mensaje.'
          : 'Mantén presionado para leer el mensaje completo.',
      label: unread
          ? 'No leída. ${notification.title}. $relative'
          : '${notification.title}. $relative',
      child: Material(
        color: AppColors.surface100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: unread
                ? AppColors.primary500.withValues(alpha: 0.55)
                : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: widget.onTap,
          onLongPress: _toggleExpanded,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeIcon(type: notification.type, unread: unread),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: _expanded ? null : 2,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: AppTextStyles.settingsRowTitle.copyWith(
                                color: AppColors.settingsTextDark,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            relative,
                            style: AppTextStyles.settingsRowCaption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notification.body,
                        maxLines: _expanded ? null : 3,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: AppTextStyles.settingsSubtitle.copyWith(
                          color: AppColors.settingsTextMuted,
                        ),
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '$date · ${unread ? 'No leída' : 'Leída'}',
                          style: AppTextStyles.settingsRowCaption.copyWith(
                            color: AppColors.settingsTextMuted,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _toggleExpanded,
                            child: const Text('Ver menos'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: AppColors.primary500,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip circular con el ícono del tipo. El relleno dorado nunca lleva ícono
/// blanco encima (regla del sistema de diseño: los `Fill` de marca son
/// claros) — va tinta oscura.
class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type, required this.unread});

  final NotificationType type;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: unread
            ? AppColors.primary500.withValues(alpha: 0.18)
            : AppColors.profileDivider,
        shape: BoxShape.circle,
      ),
      child: Icon(type.icon, size: 20, color: AppColors.settingsTextDark),
    );
  }
}
