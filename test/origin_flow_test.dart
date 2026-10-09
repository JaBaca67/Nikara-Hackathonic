import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/auth/presentation/widgets/origin_completion_gate.dart';
import 'package:nikara_app/features/profile/presentation/screens/edit_public_profile_screen.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/shared/widgets/origin_badge.dart';
import 'package:nikara_app/shared/widgets/origin_form_fields.dart';
import 'package:nikara_app/shared/widgets/origin_autocomplete_field.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/shared/widgets/public_profile_header.dart';
import 'package:nikara_app/shared/widgets/user_avatar.dart';
import 'package:nikara_app/theme/app_theme.dart';

const userId = '11111111-1111-4111-8111-111111111111';
const localOrigin = UserOrigin(
  residenceType: ResidenceType.nicaraguan,
  countryCode: 'NI',
  city: 'Masaya',
  municipality: 'Masaya',
);

void main() {
  var profile = <String, dynamic>{};
  var failLoad = false;
  var failSave = false;
  var usernameAvailable = true;
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
        } else if (request.url.path.endsWith('/rpc/username_available')) {
          body = usernameAvailable;
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
    usernameAvailable = true;
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
    await tester.tap(
      find.byType(OriginAutocompleteField<NicaraguaOriginPlace>),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciudad / municipio de origen *'),
      'masaya',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Masaya'));
    await tester.pumpAndSettle();
  }

  Future<GlobalKey<FormState>> mountOriginForm(
    WidgetTester tester,
    UserOrigin initialValue,
    ValueChanged<UserOrigin> onChanged,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: key,
              child: OriginFormFields(
                initialValue: initialValue,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets('texto escrito sin selección no permite guardar ni continuar', (
    tester,
  ) async {
    await mountGate(tester);
    await tester.tap(find.byType(DropdownButtonFormField<ResidenceType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nicaragüense').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(OriginAutocompleteField<NicaraguaOriginPlace>),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciudad / municipio de origen *'),
      'Masaya',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar y continuar'));
    await tester.tap(find.text('Guardar y continuar'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text('Contenido autorizado'), findsNothing);
    expect(find.text('Selecciona una opción de la lista.'), findsOneWidget);
  });

  testWidgets(
    'búsqueda sin tildes guarda nombres canónicos y el municipio asociado',
    (tester) async {
      UserOrigin value = const UserOrigin(
        residenceType: ResidenceType.nicaraguan,
        countryCode: 'NI',
      );
      final key = await mountOriginForm(tester, value, (v) => value = v);
      await tester.enterText(find.byType(TextFormField), 'nindiri');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Nindirí'));
      await tester.pumpAndSettle();
      expect(value.toRow()['origin_city'], 'Nindirí');
      expect(value.toRow()['origin_municipality'], 'Nindirí');
      expect(key.currentState!.validate(), isTrue);

      await tester.enterText(find.byType(TextFormField), 'puerto cabezas');
      await tester.pumpAndSettle();
      expect(value.isComplete, isFalse);
      await tester.tap(find.widgetWithText(ListTile, 'Bilwi'));
      await tester.pumpAndSettle();
      expect(value.city, 'Bilwi');
      expect(value.municipality, 'Puerto Cabezas');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets(
    'país debe elegirse del catálogo y editar el texto invalida la selección',
    (tester) async {
      UserOrigin value = const UserOrigin(residenceType: ResidenceType.foreign);
      final key = await mountOriginForm(tester, value, (v) => value = v);
      await tester.enterText(find.byType(TextFormField), 'España');
      await tester.pumpAndSettle();
      expect(value.countryCode, isNull);
      expect(key.currentState!.validate(), isFalse);
      await tester.tap(find.widgetWithText(ListTile, 'España'));
      await tester.pumpAndSettle();
      expect(value.countryCode, 'ES');
      expect(key.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField), 'Costa Rica');
      await tester.pumpAndSettle();
      expect(value.countryCode, isNull);
      expect(key.currentState!.validate(), isFalse);
      await tester.tap(find.widgetWithText(ListTile, 'Costa Rica'));
      await tester.pumpAndSettle();
      expect(value.countryCode, 'CR');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets(
    'se puede elegir una sugerencia con el teclado y borrar la selección',
    (tester) async {
      UserOrigin value = const UserOrigin(
        residenceType: ResidenceType.nicaraguan,
        countryCode: 'NI',
      );
      final key = await mountOriginForm(tester, value, (v) => value = v);
      await tester.enterText(find.byType(TextFormField), 'malpaisillo');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(value.city, 'Malpaisillo');
      expect(value.municipality, 'Larreynaga');
      expect(key.currentState!.validate(), isTrue);
      await tester.tap(find.byTooltip('Borrar selección'));
      await tester.pumpAndSettle();
      expect(value.isComplete, isFalse);
      expect(value.city, isEmpty);
      expect(value.municipality, isEmpty);
    },
  );

  testWidgets(
    'una cuenta con nombres manuales antiguos debe volver a seleccionar',
    (tester) async {
      profile.addAll({
        'residence_type': 'nicaraguan',
        'origin_country_code': 'NI',
        'origin_city': 'Mi pueblo',
        'origin_municipality': 'Mi municipio',
      });
      await mountGate(tester);
      expect(find.text('Contenido autorizado'), findsNothing);
      await tester.tap(
        find.byType(OriginAutocompleteField<NicaraguaOriginPlace>),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad / municipio de origen *'),
        'masaya',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Masaya'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar y continuar'));
      await tester.tap(find.text('Guardar y continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Contenido autorizado'), findsOneWidget);
      expect(profile['origin_city'], 'Masaya');
      expect(profile['origin_municipality'], 'Masaya');
    },
  );

  testWidgets(
    'extranjero conserva su país seleccionado al editar y no ofrece Nicaragua',
    (tester) async {
      UserOrigin value = const UserOrigin(
        residenceType: ResidenceType.foreign,
        countryCode: 'ES',
      );
      final key = await mountOriginForm(tester, value, (v) => value = v);
      expect(find.text('España'), findsOneWidget);
      expect(key.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField), 'Nicaragua');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(value.isComplete, isFalse);
      expect(key.currentState!.validate(), isFalse);
    },
  );

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
  testWidgets(
    'las sugerencias caben con teclado y texto grande en pantalla estrecha',
    (tester) async {
      tester.view.physicalSize = const Size(320, 750);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      UserOrigin value = const UserOrigin(
        residenceType: ResidenceType.nicaraguan,
        countryCode: 'NI',
      );
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: key,
                child: OriginFormFields(
                  initialValue: value,
                  onChanged: (v) => value = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byType(OriginAutocompleteField<NicaraguaOriginPlace>),
      );
      await tester.tap(
        find.byType(OriginAutocompleteField<NicaraguaOriginPlace>),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad / municipio de origen *'),
        'bluefields',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bluefields'));
      await tester.pumpAndSettle();
      expect(key.currentState!.validate(), isTrue);
      expect(value.city, 'Bluefields');
      expect(tester.takeException(), isNull);
    },
  );
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
        username: 'Ana.perez',
        origin: const UserOrigin(),
      );
      expect(invalid.success, isFalse);
      expect(signups, isEmpty);
      final result = await AuthService().signUp(
        fullName: 'Ana Pérez',
        email: 'new@example.com',
        password: 'password',
        username: 'Ana.perez',
        origin: localOrigin,
      );
      expect(result.success, isTrue);
      final metadata =
          (jsonDecode(signups.single.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      expect(metadata['origin_country_code'], 'NI');
      expect(metadata['origin_city'], 'Masaya');
      expect(metadata['origin_municipality'], 'Masaya');
      expect(metadata.containsKey('role'), isFalse);
      expect(metadata['username'], 'ana.perez');
      expect(metadata.containsKey('phone'), isFalse);
    },
  );
  test('username must be available before creating the Auth account', () async {
    usernameAvailable = false;
    final result = await AuthService().signUp(
      fullName: 'Ana Perez',
      email: 'new@example.com',
      password: 'password',
      username: 'ana.perez',
      origin: localOrigin,
    );
    expect(result.success, isFalse);
    expect(signups, isEmpty);
  });
  test(
    'settings confirm remote writes and survive another controller',
    () async {
      final first = SettingsController();
      final second = SettingsController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.loadProfile();
      await first.updateProfile(
        name: 'Ana del servidor',
        email: 'ana@example.com',
        phone: '',
        username: 'ANA.actualizada',
      );
      await first.setOffers(true);
      await second.loadProfile();
      expect(second.name, 'Ana del servidor');
      expect(second.username, 'ana.actualizada');
      expect(second.offers, isTrue);
      expect(profile['offers'], isTrue);
      expect(
        (await SharedPreferences.getInstance()).containsKey('local_username'),
        isFalse,
      );
      failSave = true;
      await first.setOffers(false);
      expect(first.offers, isTrue);
      expect(first.error, isNotNull);
      expect(profile['offers'], isTrue);
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
    await tester.tap(find.byType(OriginAutocompleteField<String>));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'País de origen *'),
      'espana',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'España'));
    await tester.pumpAndSettle();
    expect(value.countryCode, 'ES');
    expect(key.currentState!.validate(), isTrue);
  });
  testWidgets(
    'editor busca en catálogo y guarda solo ciudad y municipio canónicos',
    (tester) async {
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
      final selector = find.byType(
        OriginAutocompleteField<NicaraguaOriginPlace>,
      );
      await tester.scrollUntilVisible(
        selector,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      final search = find.widgetWithText(
        TextFormField,
        'Ciudad / municipio de origen *',
      );
      await tester.enterText(search, 'manguas');
      await tester.pumpAndSettle();
      expect(
        find.text('No hay coincidencias. Prueba con otro nombre.'),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      await tester.enterText(search, 'managua');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Managua'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Guardar cambios'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final changes = jsonDecode(writes.single.body) as Map<String, dynamic>;
      expect(changes['origin_city'], 'Managua');
      expect(changes['origin_municipality'], 'Managua');
      expect(changes['origin_country_code'], 'NI');
    },
  );

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
    expect(changes['origin_municipality'], 'Masaya');
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
