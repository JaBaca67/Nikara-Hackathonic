import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:nikara_app/core/navigation/root_navigator.dart';
import 'package:nikara_app/features/notifications/presentation/screens/notifications_screen.dart';

/// Handler de mensajes en background: FCM lo ejecuta en un isolate aparte,
/// así que tiene que ser una función de nivel superior (no un método), y no
/// puede asumir nada del estado de la app. Solo necesita existir — que el
/// sistema operativo ya se encarga de mostrar el push del payload
/// `notification` cuando la app está en background o cerrada; acá no hay
/// nada más que hacer.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Qué hacer con un push que ya llegó: mostrarlo mientras la app está
/// abierta (Android lo oculta si no se dibuja a mano) y navegar al tocarlo.
/// El registro del token del dispositivo es responsabilidad de
/// [PushTokenService] — este servicio no toca `device_push_tokens`.
///
/// Alcance deliberado del tap: siempre abre [NotificationsScreen], nunca
/// navega directo al negocio/jornada de esa notificación puntual. Esa
/// pantalla ya sabe resolver cada `type` + `reference_id` (ver `_open` en
/// `notifications_screen.dart`); reimplementar esa lógica acá, sin
/// `BuildContext` ni el ciclo de vida de un `State`, es la complejidad que no
/// vale la pena para la primera versión de push — ver CLAUDE.md.
///
/// Alcance deliberado de plataforma: solo Android. Es la única plataforma
/// donde hace falta dibujar el push a mano estando en foreground; iOS
/// (todavía no habilitado, ver CLAUDE.md) resolvería esto con
/// `setForegroundNotificationPresentationOptions` en vez de
/// `flutter_local_notifications`, y Windows/Linux ni siquiera tienen
/// `firebase_messaging` (ver `PushTokenService._platformSupportsPush`).
class PushMessageService {
  factory PushMessageService() => instance;

  PushMessageService._internal();

  static final PushMessageService instance = PushMessageService._internal();

  static const _channel = AndroidNotificationChannel(
    'notifications_default',
    'Notificaciones',
    description: 'Avisos de Níkara: negocios, jornadas ECO y reseñas.',
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _started = false;

  Future<void> startListening() async {
    if (_started || defaultTargetPlatform != TargetPlatform.android) return;
    _started = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) => _openNotifications(),
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotifications());

    // La app pudo haber arrancado *desde* el tap en el push (estaba cerrada
    // del todo) — en ese caso `onMessageOpenedApp` nunca dispara.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openNotifications();
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _openNotifications() {
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}
