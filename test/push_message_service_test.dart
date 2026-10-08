import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/notifications/data/notification_service.dart';
import 'package:nikara_app/features/notifications/data/push_message_service.dart';
import 'package:nikara_app/features/notifications/domain/models/app_notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final shown = <Map<dynamic, dynamic>>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    shown.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'show') shown.add(call.arguments as Map);
          return true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'cada tipo recibido genera un aviso nativo expandible con el mensaje íntegro',
    () async {
      final body =
          'Fecha, lugar e indicaciones completas para esta notificación. ' * 20;
      final revision = NotificationService.revision.value;
      for (final type in NotificationType.values) {
        await PushMessageService().showForegroundNotification(
          RemoteMessage(
            messageId: 'fcm-${type.wireValue}',
            data: {
              'notification_id': 'row-${type.wireValue}',
              'type': type.wireValue,
            },
            notification: RemoteNotification(
              title: 'Aviso ${type.wireValue}',
              body: body,
            ),
          ),
        );
      }
      expect(shown, hasLength(NotificationType.values.length));
      expect(
        NotificationService.revision.value,
        revision + NotificationType.values.length,
      );
      final tags = <String>{};
      for (var index = 0; index < shown.length; index++) {
        final message = shown[index];
        final android = message['platformSpecifics'] as Map;
        expect(
          message['title'],
          'Aviso ${NotificationType.values[index].wireValue}',
        );
        expect(message['body'], body);
        expect(android['channelId'], 'notifications_default');
        expect((android['styleInformation'] as Map)['bigText'], body);
        tags.add(android['tag'] as String);
      }
      expect(tags, hasLength(NotificationType.values.length));
    },
  );

  test(
    'un tipo nuevo o un aviso de datos con contenido también se muestra',
    () async {
      await PushMessageService().showForegroundNotification(
        const RemoteMessage(
          messageId: 'future-1',
          data: {
            'type': 'nuevo_tipo',
            'title': 'Aviso nuevo',
            'body': 'Texto íntegro.',
          },
        ),
      );
      expect(shown.single['title'], 'Aviso nuevo');
      expect(shown.single['body'], 'Texto íntegro.');
      expect((shown.single['platformSpecifics'] as Map)['tag'], 'future-1');
    },
  );

  test(
    'dos avisos del mismo tipo se conservan como notificaciones distintas',
    () async {
      for (final id in ['row-1', 'row-2']) {
        await PushMessageService().showForegroundNotification(
          RemoteMessage(
            data: {'notification_id': id, 'type': 'business_recommendation'},
            notification: const RemoteNotification(
              title: 'Recomendación',
              body: 'Visita un negocio.',
            ),
          ),
        );
      }
      expect(shown, hasLength(2));
      expect((shown[0]['platformSpecifics'] as Map)['tag'], 'row-1');
      expect((shown[1]['platformSpecifics'] as Map)['tag'], 'row-2');
    },
  );
}
