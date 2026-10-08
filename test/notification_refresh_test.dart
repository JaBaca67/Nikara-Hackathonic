import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/notifications/data/notification_service.dart';
import 'package:nikara_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  const me = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  final rows = <Map<String, dynamic>>[];
  final requests = <http.Request>[];

  Map<String, dynamic> row(String id, String title) => {
    'id': id,
    'user_id': me,
    'title': title,
    'body': 'Mensaje preparado para una acción del usuario.',
    'type': 'achievement_unlocked',
    'reference_id': me,
    'is_read': false,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'refresh_token': 'test-refresh',
        'user': {
          'id': me,
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2024-01-01T00:00:00Z',
        },
      }),
    );
  });

  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets(
    'la bandeja actualiza los avisos al recibir push y al volver a la app',
    (tester) async {
      rows.add(row('n-1', 'Tu primer logro'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tu primer logro'), findsOneWidget);

      rows.insert(0, row('n-2', 'Tu nueva postal'));
      NotificationService.revision.value++;
      // El aviso anterior sigue visible mientras se consulta el nuevo.
      expect(find.text('Tu primer logro'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Tu nueva postal'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      rows.insert(0, row('n-3', 'Tu próxima jornada ECO'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Tu próxima jornada ECO'), findsOneWidget);
      expect(requests, hasLength(3));
      expect(
        requests.every(
          (request) => request.url.queryParameters['user_id'] == 'eq.$me',
        ),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox());
      final queries = requests.length;
      NotificationService.revision.value++;
      await tester.pump();
      expect(requests, hasLength(queries));
    },
  );
}
