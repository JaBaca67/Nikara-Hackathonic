import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/auth/presentation/widgets/origin_completion_gate.dart';
import 'package:nikara_app/features/profile/presentation/screens/edit_public_profile_screen.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/shared/widgets/origin_badge.dart';
import 'package:nikara_app/shared/widgets/origin_form_fields.dart';
import 'package:nikara_app/shared/widgets/public_profile_header.dart';
import 'package:nikara_app/shared/widgets/user_avatar.dart';
import 'package:nikara_app/theme/app_theme.dart';

const userId = '11111111-1111-4111-8111-111111111111';
const localOrigin = UserOrigin(
  residenceType: ResidenceType.nicaraguan,
  countryCode: 'NI',
  city: 'Masaya',
  municipality: 'Nindirí',
);

void main() {
  var profile = <String, dynamic>{};
  var failLoad = false;
  var failSave = false;
  final writes = <http.Request>[];
  final signups = <http.Request>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://origin.test.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: MockClient((request) async {
        dynamic body = {};
        var status = 200;
        if (request.url.path.endsWith('/token')) {
          final expiration =
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000;
          final token =
              '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': userId, 'exp': expiration})))}.test';
          body = {
            'access_token': token,
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': userId,
              'aud': 'authenticated',
              'email': 'ana@example.com',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          };
        } else if (request.url.path.endsWith('/signup')) {
          signups.add(request);
          body = {
            'id': userId,
            'aud': 'authenticated',
            'email': 'new@example.com',
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          };
        } else if (request.url.path.endsWith('/profiles')) {
          if (request.method == 'PATCH') {
            writes.add(request);
            if (failSave) {
              status = 400;
              body = {'message': 'Write failed', 'code': '23514'};
            } else {
              profile.addAll(jsonDecode(request.body) as Map<String, dynamic>);
              body = profile;
            }
          } else if (failLoad) {
            status = 500;
            body = {'message': 'Unavailable'};
          } else {
            body = profile;
          }
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    profile = {
      'id': userId,
      'full_name': 'Ana Pérez',
      'email': 'ana@example.com',
      'role': 'turista',
    };
    writes.clear();
    signups.clear();
    failLoad = false;
    failSave = false;
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'ana@example.com',
      password: 'password',
    );
  });
  tearDown(() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  Future<void> mountGate(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OriginCompletionGate(child: Text('Contenido autorizado')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseLocal(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<ResidenceType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nicaragüense').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Masaya');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nindirí');
  }

  testWidgets('cuenta existente queda bloqueada hasta guardar su origen', (
    tester,
  ) async {
    await mountGate(tester);
    expect(find.text('Contenido autorizado'), findsNothing);
    await chooseLocal(tester);
    await tester.ensureVisible(find.text('Guardar y continuar'));
    await tester.tap(find.text('Guardar y continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Contenido autorizado'), findsOneWidget);
    expect(writes.single.url.queryParameters['id'], 'eq.$userId');
    expect(jsonDecode(writes.single.body), localOrigin.toRow());
  });
  testWidgets('sesión restaurada con origen completo entra directamente', (
    tester,
  ) async {
    profile.addAll(localOrigin.toRow());
    await mountGate(tester);
    expect(find.text('Contenido autorizado'), findsOneWidget);
    expect(writes, isEmpty);
  });
  testWidgets('error de lectura permite reintentar y mantiene bloqueo', (
    tester,
  ) async {
    failLoad = true;
    await mountGate(tester);
    expect(find.text('Contenido autorizado'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    failLoad = false;
    profile.addAll(localOrigin.toRow());
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Contenido autorizado'), findsOneWidget);
  });
  testWidgets('fallo de guardado no permite continuar', (tester) async {
    failSave = true;
    await mountGate(tester);
    await chooseLocal(tester);
    await tester.ensureVisible(find.text('Guardar y continuar'));
    await tester.tap(find.text('Guardar y continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Contenido autorizado'), findsNothing);
    expect(find.byType(OriginFormFields), findsOneWidget);
  });
  testWidgets(
    'residencia obligatoria y cambio a extranjero limpia los lugares',
    (tester) async {
      final key = GlobalKey<FormState>();
      UserOrigin value = const UserOrigin();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: key,
                child: OriginFormFields(onChanged: (v) => value = v),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await chooseLocal(tester);
      expect(value.isComplete, isTrue);
      await tester.tap(find.byType(DropdownButtonFormField<ResidenceType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extranjero').last);
      await tester.pumpAndSettle();
      expect(value.city, isEmpty);
      expect(value.municipality, isEmpty);
      expect(key.currentState!.validate(), isFalse);
      expect(find.text('País de origen *'), findsOneWidget);
    },
  );
  test(
    'registro valida procedencia y la envía en metadatos antes del trigger',
    () async {
      final invalid = await AuthService().signUp(
        fullName: 'Ana Pérez',
        email: 'new@example.com',
        password: 'password',
        phone: '+505 88888888',
        origin: const UserOrigin(),
      );
      expect(invalid.success, isFalse);
      expect(signups, isEmpty);
      final result = await AuthService().signUp(
        fullName: 'Ana Pérez',
        email: 'new@example.com',
        password: 'password',
        phone: '+505 88888888',
        origin: localOrigin,
      );
      expect(result.success, isTrue);
      final metadata =
          (jsonDecode(signups.single.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      expect(metadata['origin_country_code'], 'NI');
      expect(metadata['origin_city'], 'Masaya');
      expect(metadata['origin_municipality'], 'Nindirí');
      expect(metadata.containsKey('role'), isFalse);
    },
  );
  testWidgets('extranjero puede buscar su país sin tildes', (tester) async {
    final key = GlobalKey<FormState>();
    UserOrigin value = const UserOrigin(residenceType: ResidenceType.foreign);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Form(
            key: key,
            child: OriginFormFields(
              initialValue: value,
              onChanged: (v) => value = v,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InputDecorator).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'espana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('España'));
    await tester.pumpAndSettle();
    expect(value.countryCode, 'ES');
    expect(key.currentState!.validate(), isTrue);
  });
  testWidgets('editor guarda nombre, bio y privacidad solamente en su cuenta', (
    tester,
  ) async {
    profile.addAll(localOrigin.toRow());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: '/edit',
        routes: {
          '/': (_) => const Scaffold(),
          '/edit': (_) =>
              EditPublicProfileScreen(profile: UserModel.fromRow(profile)),
        },
      ),
    );
    await tester.pumpAndSettle();
    final name = find.byType(TextFormField).first;
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Ana viajera');
    final bio = find.byType(TextFormField).at(1);
    await tester.ensureVisible(bio);
    await tester.enterText(bio, 'Me gusta la cultura.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final visibility = find.widgetWithText(
      SwitchListTile,
      'Mostrar mi procedencia',
    );
    await tester.scrollUntilVisible(
      visibility,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(visibility);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar cambios'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    final changes = jsonDecode(writes.single.body) as Map<String, dynamic>;
    expect(changes['public_display_name'], 'Ana viajera');
    expect(changes['bio'], 'Me gusta la cultura.');
    expect(changes['show_origin'], isFalse);
    expect(changes['origin_municipality'], 'Nindirí');
    expect(changes.containsKey('email'), isFalse);
    expect(changes.containsKey('role'), isFalse);
    expect(writes.single.url.queryParameters['id'], 'eq.$userId');
  });
  testWidgets('editor e insignia admiten pantalla pequeña y texto grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longProfile = UserModel.fromRow({
      ...profile,
      ...localOrigin.toRow(),
      'public_display_name':
          'Viajera de Nicaragua con un nombre público muy largo',
      'bio': 'Me gusta explorar los lugares culturales de Nicaragua.',
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: EditPublicProfileScreen(profile: longProfile),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OriginBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cabecera personal conserva el recorte circular', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PublicProfileHeader(
            name: 'Ana',
            avatar: const UserAvatar(avatarUrl: null, initials: 'AP'),
            accent: AppColors.neutral1100,
            circularAvatar: true,
            onBack: () {},
          ),
        ),
      ),
    );
    final clips = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
    expect(
      clips.any((clip) => clip.borderRadius == BorderRadius.circular(100)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
