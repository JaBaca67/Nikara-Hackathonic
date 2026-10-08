import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';
import 'package:nikara_app/features/notifications/domain/models/app_notification.dart';
import 'package:nikara_app/features/notifications/domain/models/notification_message.dart';

const _me = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

String _session(String userId) => jsonEncode({
  'access_token': 'test-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'test-refresh',
  'user': {
    'id': userId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2024-01-01T00:00:00Z',
  },
});

BusinessModel _business(
  String id, {
  ReviewStatus status = ReviewStatus.aprobado,
}) => BusinessModel(
  id: id,
  name: 'Café $id',
  category: 'Gastronomía',
  description: '',
  city: 'Matagalpa',
  locationText: '',
  contactPhone: '',
  hostName: '',
  reviewStatus: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rows = <Map<String, dynamic>>[];
  final requests = <http.Request>[];
  var failInsert = false;
  Completer<void>? readGate;
  final businesses = [
    _business('cafe-1'),
    _business('cafe-2'),
    _business('cafe-3'),
    _business('cafe-4'),
  ];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/notifications')) {
          if (request.method == 'GET') {
            final gate = readGate;
            if (gate != null) await gate.future;
            final userFilter = request.url.queryParameters['user_id'];
            return http.Response(
              jsonEncode([
                for (final row in rows)
                  if (userFilter == 'eq.${row['user_id']}' &&
                      [
                        'demo_welcome',
                        'business_recommendation',
                      ].contains(row['type']))
                    {'type': row['type']},
              ]),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.method == 'POST') {
            if (failInsert) {
              return http.Response(
                jsonEncode({'code': '42501', 'message': 'Error simulado'}),
                403,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            rows.addAll(
              (jsonDecode(request.body) as List).cast<Map<String, dynamic>>(),
            );
            return http.Response('', 201, request: request);
          }
        }
        if (request.url.path.endsWith('/logout')) {
          return http.Response('', 204, request: request);
        }
        throw StateError('Petición inesperada: ${request.url}');
      }),
    );
  });

  setUp(() async {
    rows.clear();
    requests.clear();
    failInsert = false;
    readGate = null;
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(_session(_me));
  });

  tearDownAll(() => Supabase.instance.dispose());

  test(
    'Inicio genera cinco avisos propios y tres destinos de negocios',
    () async {
      final revision = NotificationService.revision.value;
      await NotificationService().ensureDemoNotifications(businesses);

      expect(rows, hasLength(5));
      expect(rows.every((row) => row['user_id'] == _me), isTrue);
      expect(rows.every((row) => row['is_read'] == false), isTrue);
      final recommendations = rows.where(
        (row) => row['type'] == 'business_recommendation',
      );
      expect(recommendations.map((row) => row['reference_id']), [
        'cafe-1',
        'cafe-2',
        'cafe-3',
      ]);
      for (final row in recommendations) {
        final notification = AppNotification.fromRow(row);
        expect(notification.isNavigable, isTrue);
        expect(notification.type.target, NotificationTarget.business);
        expect(notification.body, contains('Matagalpa'));
      }
      expect(NotificationService.revision.value, revision + 1);
      expect(requests.first.url.queryParameters['user_id'], 'eq.$_me');
    },
  );

  test('recargas simultáneas y posteriores no repiten el lote', () async {
    await Future.wait([
      NotificationService().ensureDemoNotifications(businesses),
      NotificationService().ensureDemoNotifications(businesses),
    ]);
    await NotificationService().ensureDemoNotifications(businesses);
    expect(rows, hasLength(5));
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));

    // Borrar los avisos no los vuelve a generar en este dispositivo.
    rows.clear();
    await NotificationService().ensureDemoNotifications(businesses);
    expect(rows, isEmpty);
  });

  test(
    'la base evita duplicados sin recibo local, incluso si ya están leídos',
    () async {
      rows.addAll(
        [
          ...NotificationMessage.welcome,
          ...NotificationMessage.recommendations(businesses),
        ].map((message) => {...message.toRow(_me), 'is_read': true}),
      );

      await NotificationService().ensureDemoNotifications(businesses);
      expect(rows, hasLength(5));
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test(
    'con catálogo vacío envía bienvenida y completa recomendaciones después',
    () async {
      await NotificationService().ensureDemoNotifications([]);
      expect(rows, hasLength(2));
      await NotificationService().ensureDemoNotifications(businesses);
      expect(rows, hasLength(5));
      expect(rows.where((row) => row['type'] == 'demo_welcome'), hasLength(1));
    },
  );

  test('un fallo permite reintentar y no actualiza el contador', () async {
    final revision = NotificationService.revision.value;
    failInsert = true;
    await NotificationService().ensureDemoNotifications(businesses);
    expect(rows, isEmpty);
    expect(NotificationService.revision.value, revision);
    failInsert = false;
    await NotificationService().ensureDemoNotifications(businesses);
    expect(rows, hasLength(5));
  });

  test(
    'las marcas y los destinatarios se mantienen separados por cuenta',
    () async {
      await NotificationService().ensureDemoNotifications(businesses);
      await Supabase.instance.client.auth.recoverSession(_session(_other));
      await NotificationService().ensureDemoNotifications(businesses);
      expect(rows.where((row) => row['user_id'] == _me), hasLength(5));
      expect(rows.where((row) => row['user_id'] == _other), hasLength(5));
    },
  );

  test(
    'cambiar de cuenta durante la lectura cancela el lote anterior',
    () async {
      readGate = Completer<void>();
      final delivery = NotificationService().ensureDemoNotifications(
        businesses,
      );
      while (requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await Supabase.instance.client.auth.recoverSession(_session(_other));
      readGate!.complete();
      await delivery;
      expect(rows, isEmpty);
    },
  );

  test('un invitado no recibe avisos ni hace consultas', () async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    requests.clear();
    await NotificationService().ensureDemoNotifications(businesses);
    expect(rows, isEmpty);
    expect(requests, isEmpty);
  });

  test('recomendaciones excluyen negocios sin aprobar y repetidos', () {
    final messages = NotificationMessage.recommendations([
      _business('pendiente', status: ReviewStatus.pendiente),
      _business('rechazado', status: ReviewStatus.rechazado),
      _business('aprobado'),
      _business('aprobado'),
    ]);
    expect(messages, hasLength(1));
    expect(messages.single.referenceId, 'aprobado');
  });

  test(
    'la preparación usa requisitos reales y no anuncia un recordatorio futuro',
    () {
      final activity = EcoActivityModel.fromRow({
        'id': 'jornada-1',
        'title': 'Limpieza de playa',
        'category': 'Limpieza',
        'location': 'Pochomil',
      'start_time': '2026-10-15T14:00:00Z',
      'created_at': '2026-10-08T14:00:00Z',
      'requirements': ['Guantes', '  ', 'Botella reutilizable'],
      });
      final messages = NotificationMessage.participation(activity);
      expect(messages.first.body, contains('Pochomil'));
      expect(messages.first.body, contains('15 de octubre, 2026'));
      expect(messages.last.body, contains('Guantes; Botella reutilizable'));
      expect(messages.last.type, NotificationType.ecoActivityPreparation);
      expect(messages.every((m) => m.referenceId == activity.id), isTrue);
    },
  );
}
