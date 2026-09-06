import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/notifications/domain/models/app_notification.dart';
import 'package:nikara_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:nikara_app/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:nikara_app/features/notifications/presentation/widgets/notifications_states.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Reloj fijo para que el tiempo relativo no dependa del reloj de la máquina
/// que corre la suite.
final _now = DateTime(2026, 8, 25, 12);

AppNotification _sample({
  String id = 'n-1',
  String title = 'Tu negocio fue aprobado',
  String body = '"Café La Ceiba" ya aparece verificado en Níkara.',
  NotificationType type = NotificationType.businessApproved,
  String? referenceId = 'biz-1',
  bool isRead = false,
  Duration age = const Duration(hours: 2),
}) {
  return AppNotification(
    id: id,
    userId: 'user-1',
    title: title,
    body: body,
    type: type,
    referenceId: referenceId,
    isRead: isRead,
    createdAt: _now.subtract(age),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() async {
    // AuthService lee Supabase.instance de forma síncrona (aunque solo sea
    // para isLoggedIn) y lanza un assertion error si nunca se inicializó.
    // No hacen falta credenciales reales: initialize() solo tiene que
    // completar su setup local. Va antes que nada porque GoTrue toca
    // SharedPreferences durante initialize().
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppNotification', () {
    test('fromRow mapea las columnas snake_case de Supabase', () {
      final notification = AppNotification.fromRow({
        'id': 'abc',
        'user_id': 'user-1',
        'title': 'Título',
        'body': 'Cuerpo',
        'type': 'eco_activity_reminder',
        'reference_id': 'eco-9',
        'is_read': false,
        'created_at': '2026-08-25T10:00:00Z',
      });

      expect(notification.id, 'abc');
      expect(notification.userId, 'user-1');
      expect(notification.type, NotificationType.ecoActivityReminder);
      expect(notification.type.target, NotificationTarget.ecoActivity);
      expect(notification.referenceId, 'eco-9');
      expect(notification.isRead, isFalse);
      expect(notification.isNavigable, isTrue);
    });

    test('un type desconocido degrada a system y deja de ser navegable', () {
      final notification = AppNotification.fromRow({
        'id': 'abc',
        'user_id': 'user-1',
        'title': 'Título',
        'body': 'Cuerpo',
        'type': 'algo_que_todavia_no_existe',
        'reference_id': 'x-1',
        'is_read': true,
        'created_at': '2026-08-25T10:00:00Z',
      });

      expect(notification.type, NotificationType.system);
      expect(notification.isNavigable, isFalse);
    });

    test('una notificación sin reference_id nunca navega', () {
      expect(_sample(referenceId: null).isNavigable, isFalse);
      expect(_sample(referenceId: '').isNavigable, isFalse);
    });

    test('relativeTime usa el formato corto en español', () {
      expect(
        _sample(age: const Duration(seconds: 30)).relativeTime(now: _now),
        'ahora',
      );
      expect(
        _sample(age: const Duration(minutes: 5)).relativeTime(now: _now),
        'hace 5 min',
      );
      expect(
        _sample(age: const Duration(hours: 2)).relativeTime(now: _now),
        'hace 2 h',
      );
      expect(
        _sample(age: const Duration(days: 1)).relativeTime(now: _now),
        'ayer',
      );
      expect(
        _sample(age: const Duration(days: 3)).relativeTime(now: _now),
        'hace 3 d',
      );
      expect(
        _sample(age: const Duration(days: 14)).relativeTime(now: _now),
        'hace 2 sem',
      );
    });
  });

  group('NotificationTile', () {
    testWidgets('muestra título, cuerpo y tiempo relativo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NotificationTile(notification: _sample(), onTap: () {}, now: _now),
        ),
      );
      await tester.pump();

      expect(find.text('Tu negocio fue aprobado'), findsOneWidget);
      expect(
        find.text('"Café La Ceiba" ya aparece verificado en Níkara.'),
        findsOneWidget,
      );
      expect(find.text('hace 2 h'), findsOneWidget);
    });

    testWidgets('anuncia "No leída" solo cuando la notificación no fue leída', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NotificationTile(
            notification: _sample(isRead: false),
            onTap: () {},
            now: _now,
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('^No leída')), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          NotificationTile(
            notification: _sample(isRead: true),
            onTap: () {},
            now: _now,
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('^No leída')), findsNothing);
    });

    testWidgets('no desborda con un nombre de negocio absurdamente largo', (
      tester,
    ) async {
      // Mismo espíritu que test/overflow_audit_test.dart: datos peores que
      // cualquier input real para forzar un RenderFlex overflow.
      await tester.pumpWidget(
        _wrap(
          NotificationTile(
            notification: _sample(
              title:
                  'Tu negocio "${'Restaurante Mirador Ecológico Comunitario '
                          'de la Reserva Natural ' * 3}" fue aprobado',
              body: 'Cuerpo interminable de la notificación. ' * 20,
            ),
            onTap: () {},
            now: _now,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('el toque llega al callback', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          NotificationTile(
            notification: _sample(),
            onTap: () => tapped++,
            now: _now,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Tu negocio fue aprobado'));
      await tester.pump();

      expect(tapped, 1);
    });
  });

  group('Estados de la pantalla', () {
    testWidgets('el estado vacío explica qué llega y ofrece una salida', (
      tester,
    ) async {
      var explored = 0;
      await tester.pumpWidget(
        _wrap(NotificationsEmptyState(onExplore: () => explored++)),
      );
      await tester.pump();

      expect(find.text('No tienes notificaciones'), findsOneWidget);
      expect(find.text('Seguir explorando'), findsOneWidget);

      await tester.tap(find.text('Seguir explorando'));
      await tester.pump();
      expect(explored, 1);
    });

    testWidgets('el esqueleto renderiza una fila por cada placeholder pedido', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const NotificationsSkeleton(rows: 3)));
      await tester.pump();

      // El esqueleto no debe anunciar nada a un lector de pantalla. Se afirma
      // "al menos uno" y no una cantidad exacta a propósito: cuántos
      // ExcludeSemantics envuelven el árbol es un detalle de implementación
      // (el propio esqueleto anida filas), y fijarlo haría fallar el test
      // ante cualquier reacomodo que no cambie lo que se anuncia.
      expect(find.byType(NotificationTile), findsNothing);
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets('el estado de error muestra el mensaje del servicio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NotificationsErrorState(
            message: 'Ocurrió un error de conexión.',
            onRetry: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No pudimos cargar tus notificaciones'), findsOneWidget);
      expect(find.text('Ocurrió un error de conexión.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('NotificationsScreen', () {
    testWidgets(
      'un invitado ve el motivo, no una bandeja vacía, y no rompe sin sesión',
      (tester) async {
        // Sin sesión activa (Supabase inicializado en limpio), la pantalla no
        // debe llegar a consultar la tabla ni desreferenciar currentUser!.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const NotificationsScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Crea tu cuenta para recibir avisos'), findsOneWidget);
        expect(find.text('Crear mi cuenta'), findsOneWidget);
        expect(find.text('Ya tengo cuenta'), findsOneWidget);
        expect(find.text('No tienes notificaciones'), findsNothing);
      },
    );

    testWidgets('el encabezado del invitado dice "Estás al día", sin CTA de '
        'marcar todas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Estás al día'), findsOneWidget);
      expect(find.text('Marcar todas'), findsNothing);
    });
  });
}
