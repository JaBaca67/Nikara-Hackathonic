import 'package:flutter/material.dart';

/// A dónde lleva tocar una notificación. El destino no se guarda en la base:
/// se deriva de [NotificationType], así que agregar un tipo nuevo obliga a
/// decidir su navegación acá y no en cada pantalla que la muestre.
enum NotificationTarget {
  /// Abre el detalle del negocio cuyo id viaja en `reference_id`.
  business,

  /// Abre el detalle de la jornada ECO cuyo id viaja en `reference_id`.
  ecoActivity,

  /// Informativa: al tocarla solo se marca como leída.
  none,
}

/// Valores de la columna `notifications.type` (texto libre en Postgres, sin
/// enum nativo — ver `docs/database_erd.md`). [wireValue] es exactamente el
/// string que viaja a la base; el nombre en Dart es camelCase por convención.
enum NotificationType {
  businessApproved(
    'business_approved',
    Icons.verified_rounded,
    NotificationTarget.business,
  ),
  businessUnverified(
    'business_unverified',
    Icons.gpp_maybe_rounded,
    NotificationTarget.business,
  ),
  ecoActivityJoined(
    'eco_activity_joined',
    Icons.eco_rounded,
    NotificationTarget.ecoActivity,
  ),
  ecoActivityReminder(
    'eco_activity_reminder',
    Icons.alarm_rounded,
    NotificationTarget.ecoActivity,
  ),
  system('system', Icons.notifications_rounded, NotificationTarget.none);

  const NotificationType(this.wireValue, this.icon, this.target);

  final String wireValue;
  final IconData icon;
  final NotificationTarget target;

  /// Un `type` desconocido (fila vieja, o escrita por una versión posterior
  /// de la app) degrada a [system] en vez de romper el listado completo:
  /// la notificación se sigue viendo, solo que no navega a ningún lado.
  static NotificationType fromWire(Object? value) {
    final raw = value?.toString();
    for (final type in NotificationType.values) {
      if (type.wireValue == raw) return type;
    }
    return NotificationType.system;
  }
}

/// Una fila de `notifications`. `user_id` es el **destinatario**, no quien
/// generó el aviso — por eso el modelo no expone ningún campo de autor.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final createdAtRaw = row['created_at']?.toString();
    return AppNotification(
      id: row['id'].toString(),
      userId: row['user_id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      type: NotificationType.fromWire(row['type']),
      referenceId: row['reference_id']?.toString(),
      isRead: row['is_read'] == true,
      createdAt:
          DateTime.tryParse(createdAtRaw ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;

  /// Id polimórfico del recurso al que apunta [type]; sin FK real en la base,
  /// así que puede quedar huérfano si el recurso se eliminó.
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  bool get isNavigable =>
      type.target != NotificationTarget.none &&
      (referenceId?.isNotEmpty ?? false);

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  /// Antigüedad en formato corto ("hace 2 h"). [now] existe para que los
  /// tests no dependan del reloj real.
  String relativeTime({DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(createdAt);
    // Un `created_at` en el futuro (reloj del teléfono atrasado frente al del
    // servidor) se lee como "ahora" en vez de "hace -3 min".
    if (elapsed.inMinutes < 1) return 'ahora';
    if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
    if (elapsed.inDays == 1) return 'ayer';
    if (elapsed.inDays < 7) return 'hace ${elapsed.inDays} d';
    if (elapsed.inDays < 30) return 'hace ${elapsed.inDays ~/ 7} sem';
    final months = elapsed.inDays ~/ 30;
    return months <= 1 ? 'hace 1 mes' : 'hace $months meses';
  }
}
