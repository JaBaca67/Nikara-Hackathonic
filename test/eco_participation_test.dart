import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_main_screen.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _me = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _other1 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
const _other2 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
const _activityId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

const _joinedMsg = '¡Te uniste a la actividad!';
const _leftMsg = 'Saliste de la actividad';
const _retry = 'Reintentar';

/// Sesión persistida con la forma que guarda `supabase_flutter`, vigente una
/// hora: al iniciar se restaura sin tocar la red.
String _sessionJson() => jsonEncode({
  'access_token': 'token-falso',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'refresh-falso',
  'user': {
    'id': _me,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2024-01-01T00:00:00Z',
  },
});

/// "Servidor" simulado de `eco_activities` / `eco_participants`.
class _FakeEco {
  /// Quién está inscrito ahora mismo.
  List<String> participants = [_other1];
  int? capacity = 5;
  DateTime start = DateTime.now().add(const Duration(days: 3));

  /// Si es falso, todo responde con un error 500 (lecturas y escrituras).
  bool up = true;

  /// Solo las escrituras cortan la conexión (la lectura previa sí responde).
  bool writesDropConnection = false;

  /// Mientras no sea nulo, la inscripción (POST) espera a que se complete.
  Completer<void>? postGate;

  /// Las próximas N lecturas devuelven la actividad sin mí aunque ya esté
  /// inscrito: la copia vieja que ve una pantalla abierta hace rato.
  int staleReads = 0;

  int posts = 0;
  int deletes = 0;

  Map<String, dynamic> row({bool hideMe = false}) => {
    'id': _activityId,
    'title': 'Limpieza de playa',
    'description': 'Jornada de limpieza.',
    'category': 'Limpieza',
    'location': 'Pochomil',
    'start_time': start.toUtc().toIso8601String(),
    'max_capacity': capacity,
    'created_at': '2024-01-01T00:00:00Z',
    'status': 'aprobado',
    'eco_participants': [
      for (final id in participants)
        if (!(hideMe && id == _me))
          {'user_id': id, 'joined_at': '2024-02-01T00:00:00Z'},
    ],
  };

  http.Response _error(http.BaseRequest request) => http.Response(
    jsonEncode({'message': 'servidor caído (simulado)', 'code': 'PGRST000'}),
    500,
    request: request,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Client get client => MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/eco_activities') && request.method == 'GET') {
      if (!up) return _error(request);
      final hide = staleReads > 0;
      if (hide) staleReads--;
      return http.Response(
        jsonEncode([row(hideMe: hide)]),
        200,
        request: request,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path.endsWith('/eco_participants')) {
      if (!up) return _error(request);
      if (writesDropConnection) {
        throw http.ClientException('Sin conexión (simulada)');
      }
      if (request.method == 'POST') {
        posts++;
        final gate = postGate;
        if (gate != null) await gate.future;
        participants.add(_me);
        return http.Response('', 201, request: request);
      }
      if (request.method == 'DELETE') {
        deletes++;
        participants.remove(_me);
        return http.Response('', 204, request: request);
      }
    }
    return _error(request);
  });
}

void main() {
  final eco = _FakeEco();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'sb-example-auth-token': _sessionJson(),
    });
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: eco.client,
    );
  });

  setUp(() async {
    eco
      ..participants = [_other1]
      ..capacity = 5
      ..start = DateTime.now().add(const Duration(days: 3))
      ..up = true
      ..writesDropConnection = false
      ..postGate = null
      ..staleReads = 0
      ..posts = 0
      ..deletes = 0;
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(_sessionJson());
  });

  EcoActivityModel modelFromServer() =>
      EcoActivityModel.fromRow(eco.row(), currentUserId: _me);

  Future<void> letAsyncWorkRun(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: EcoDetailScreen(activity: modelFromServer()),
      ),
    );
    await letAsyncWorkRun(tester);
  }

  Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await letAsyncWorkRun(tester);
  }

  Finder snack(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  group('unirse', () {
    testWidgets('con éxito: un solo aviso y el botón pasa a "Abandonar"', (
      tester,
    ) async {
      await openDetail(tester);
      expect(find.text('Unirme'), findsOneWidget);

      await tapAndWait(tester, find.text('Unirme'));

      expect(eco.posts, 1);
      expect(snack(_joinedMsg), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget, reason: 'un solo aviso');
      expect(find.text('Abandonar actividad'), findsOneWidget);
      expect(find.text('Unirme'), findsNothing);
      // El estado se actualiza al instante, sin recargar la pantalla.
      expect(find.text('Participando'), findsOneWidget);
    });

    testWidgets('sin conexión: error con "Reintentar" y el botón no cambia', (
      tester,
    ) async {
      await openDetail(tester);
      eco.writesDropConnection = true;

      await tapAndWait(tester, find.text('Unirme'));

      expect(
        snack(
          'Sin conexión. No se pudo completar la inscripción. Verifica tu '
          'internet e intenta de nuevo.',
        ),
        findsOneWidget,
      );
      expect(snack(_retry), findsOneWidget);
      expect(snack(_joinedMsg), findsNothing);
      // No finge que te uniste.
      expect(find.text('Unirme'), findsOneWidget);
      expect(find.text('Abandonar actividad'), findsNothing);
      expect(
        tester
            .widget<AppLoadingButton>(find.byType(AppLoadingButton))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('"Reintentar" vuelve a intentarlo y, si ahora funciona, une', (
      tester,
    ) async {
      await openDetail(tester);
      eco.writesDropConnection = true;
      await tapAndWait(tester, find.text('Unirme'));
      expect(snack(_retry), findsOneWidget);

      eco.writesDropConnection = false;
      await tapAndWait(tester, find.text(_retry));

      expect(eco.posts, 1);
      expect(snack(_joinedMsg), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Abandonar actividad'), findsOneWidget);
    });

    testWidgets('un error del servidor se muestra sin texto técnico', (
      tester,
    ) async {
      await openDetail(tester);
      eco.up = false;

      await tapAndWait(tester, find.text('Unirme'));

      expect(
        snack(
          'No se pudo completar la inscripción. Intenta de nuevo en un '
          'momento.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PGRST'), findsNothing);
      expect(find.textContaining('servidor caído'), findsNothing);
      expect(snack(_retry), findsOneWidget);
      expect(find.text('Unirme'), findsOneWidget);
    });

    testWidgets('el segundo toque mientras guarda no inscribe dos veces', (
      tester,
    ) async {
      await openDetail(tester);
      eco.postGate = Completer<void>();

      await tapAndWait(tester, find.text('Unirme'));

      // En curso: spinner dentro del botón, que ya no tiene etiqueta.
      expect(eco.posts, 1);
      expect(
        find.descendant(
          of: find.byType(AppLoadingButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('Unirme'), findsNothing);

      await tester.tap(find.byType(AppLoadingButton), warnIfMissed: false);
      await letAsyncWorkRun(tester);
      expect(eco.posts, 1);

      eco.postGate!.complete();
      await letAsyncWorkRun(tester);
      await letAsyncWorkRun(tester);

      expect(eco.posts, 1);
      expect(snack(_joinedMsg), findsOneWidget);
      expect(find.text('Abandonar actividad'), findsOneWidget);
    });

    testWidgets('actividad llena: lo explica y no inscribe', (tester) async {
      eco.capacity = 2;
      eco.participants = [_other1, _other2];
      await openDetail(tester);

      await tapAndWait(tester, find.text('Unirme'));

      expect(
        snack('La actividad está llena: ya no quedan cupos.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(eco.posts, 0, reason: 'no se intentó inscribir');
      expect(snack(_retry), findsNothing, reason: 'no hay nada que reintentar');
      expect(find.text('Unirme'), findsOneWidget);
    });

    testWidgets('se llenó mientras la pantalla estaba abierta', (tester) async {
      eco.capacity = 2;
      eco.participants = [_other1];
      await openDetail(tester);
      expect(find.text('Unirme'), findsOneWidget);

      // Otra persona toma el último cupo después de que se abrió la pantalla.
      eco.participants = [_other1, _other2];
      await tapAndWait(tester, find.text('Unirme'));

      expect(
        snack('La actividad está llena: ya no quedan cupos.'),
        findsOneWidget,
      );
      expect(eco.posts, 0);
    });

    testWidgets('ya inscrito (copia vieja): lo explica y se pone al día', (
      tester,
    ) async {
      eco.participants = [_other1, _me];
      eco.staleReads = 1; // la apertura de la pantalla ve la copia vieja
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EcoDetailScreen(
            activity: EcoActivityModel.fromRow(
              eco.row(hideMe: true),
              currentUserId: _me,
            ),
          ),
        ),
      );
      await letAsyncWorkRun(tester);
      expect(find.text('Unirme'), findsOneWidget);

      await tapAndWait(tester, find.text('Unirme'));

      expect(snack('Ya estás inscrito en esta actividad.'), findsOneWidget);
      expect(eco.posts, 0);
      expect(find.text('Abandonar actividad'), findsOneWidget);
    });

    test(
      'actividad finalizada: el servicio lo rechaza con su motivo',
      () async {
        eco.start = DateTime.now().subtract(const Duration(days: 1));

        await expectLater(
          EcoService().joinActivity(_activityId),
          throwsA(
            isA<EcoParticipationException>()
                .having(
                  (e) => e.failure,
                  'failure',
                  EcoParticipationFailure.ended,
                )
                .having(
                  (e) => e.message,
                  'message',
                  'Esta actividad ya finalizó.',
                ),
          ),
        );
        expect(eco.posts, 0);
      },
    );
  });

  group('salir', () {
    Future<void> openJoined(WidgetTester tester) async {
      eco.participants = [_other1, _me];
      await openDetail(tester);
      expect(find.text('Abandonar actividad'), findsOneWidget);
    }

    testWidgets('pide confirmar y "Cancelar" no sale', (tester) async {
      await openJoined(tester);

      await tapAndWait(tester, find.text('Abandonar actividad'));
      expect(find.text('¿Salir de la actividad?'), findsOneWidget);

      await tapAndWait(tester, dialogButton('Cancelar'));

      expect(eco.deletes, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Abandonar actividad'), findsOneWidget);
    });

    testWidgets('confirmar sale, avisa una vez y vuelve "Unirme"', (
      tester,
    ) async {
      await openJoined(tester);

      await tapAndWait(tester, find.text('Abandonar actividad'));
      await tapAndWait(tester, dialogButton('Salir'));

      expect(eco.deletes, 1);
      expect(snack(_leftMsg), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Unirme'), findsOneWidget);
      expect(find.text('Abandonar actividad'), findsNothing);
    });

    testWidgets('si falla, "Reintentar" sale sin volver a preguntar', (
      tester,
    ) async {
      await openJoined(tester);
      eco.writesDropConnection = true;

      await tapAndWait(tester, find.text('Abandonar actividad'));
      await tapAndWait(tester, dialogButton('Salir'));

      expect(
        snack(
          'Sin conexión. No se pudo salir de la actividad. Verifica tu '
          'internet e intenta de nuevo.',
        ),
        findsOneWidget,
      );
      expect(snack(_leftMsg), findsNothing);
      // Sigue inscrito: no finge que saliste.
      expect(find.text('Abandonar actividad'), findsOneWidget);

      eco.writesDropConnection = false;
      await tapAndWait(tester, find.text(_retry));

      expect(find.byType(AlertDialog), findsNothing, reason: 'sin pregunta');
      expect(eco.deletes, 1);
      expect(snack(_leftMsg), findsOneWidget);
      expect(find.text('Unirme'), findsOneWidget);
    });
  });

  group('pantalla principal de ECO (tarjeta destacada)', () {
    Future<void> openMain(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const EcoMainScreen()),
      );
      await letAsyncWorkRun(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      // La pantalla abre un canal Realtime; al cerrarlo agenda un timer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    }

    testWidgets('"Unirme" une, avisa una vez y la tarjeta pasa a "Unido"', (
      tester,
    ) async {
      await openMain(tester);
      expect(find.text('Unirme'), findsOneWidget);

      await tapAndWait(tester, find.text('Unirme'));

      expect(eco.posts, 1);
      expect(snack(_joinedMsg), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Unido'), findsOneWidget);
      expect(find.text('Unirme'), findsNothing);

      await unmount(tester);
    });

    testWidgets('si falla, avisa con "Reintentar" y la tarjeta no cambia', (
      tester,
    ) async {
      await openMain(tester);
      eco.writesDropConnection = true;

      await tapAndWait(tester, find.text('Unirme'));

      expect(snack(_retry), findsOneWidget);
      expect(find.text('Unirme'), findsOneWidget);
      expect(find.text('Unido'), findsNothing);

      await unmount(tester);
    });

    testWidgets('"Unido" pide confirmar antes de salir', (tester) async {
      eco.participants = [_other1, _me];
      await openMain(tester);
      expect(find.text('Unido'), findsOneWidget);

      await tapAndWait(tester, find.text('Unido'));
      expect(find.text('¿Salir de la actividad?'), findsOneWidget);
      expect(eco.deletes, 0);

      await tapAndWait(tester, dialogButton('Salir'));
      expect(eco.deletes, 1);
      expect(snack(_leftMsg), findsOneWidget);
      expect(find.text('Unirme'), findsOneWidget);

      await unmount(tester);
    });
  });
}
