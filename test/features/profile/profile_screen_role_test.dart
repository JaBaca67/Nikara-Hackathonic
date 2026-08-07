import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';

/// Visual/render verification for the client-vs-owner role hierarchy: this
/// pumps the real [ProfileScreen] widget tree (not a mock) for each Dev
/// Mode identity and asserts both on content (the right sections show up)
/// and on `tester.takeException()` being null — which is how Flutter
/// widget tests surface a `RenderFlex overflowed` error, since there is no
/// real device screenshot pipeline available in this environment.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().resetForTesting();
  });

  Widget harness() => const MaterialApp(home: ProfileScreen());

  /// A narrow phone width is where RenderFlex overflows are most likely to
  /// surface (long names/prices with not enough room to ellipsize).
  void useNarrowScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Client role (Sofía, default) hides Mis Negocios and renders cleanly',
    (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Mis Negocios'), findsNothing);
      // The Puntos stat reflects Sofía's seeded points.
      expect(find.text('45'), findsOneWidget);
      expect(find.text('Dev Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Switching to Carlos (owner) reveals Mis Negocios with his fixture businesses',
    (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      AuthService().signInAs(kCarlosUserId);
      await tester.pumpAndSettle();

      expect(find.text('Mis Negocios'), findsOneWidget);
      expect(find.text('Mirador El Boquete'), findsOneWidget);
      expect(find.text('Café Selva Nublada'), findsOneWidget);
      expect(find.text('320'), findsOneWidget);
      expect(find.text('Editar'), findsWidgets);
      expect(find.text('Eliminar'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Switching back to Sofía after Carlos hides Mis Negocios again',
    (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      AuthService().signInAs(kCarlosUserId);
      await tester.pumpAndSettle();
      expect(find.text('Mis Negocios'), findsOneWidget);

      AuthService().signInAs(kSofiaUserId);
      await tester.pumpAndSettle();

      expect(find.text('Mis Negocios'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'The Dev Mode FAB opens the role switcher sheet and Carlos can be selected from it',
    (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dev Mode'));
      await tester.pumpAndSettle();

      expect(find.text('🧪 Cambiar perfil (Dev Mode)'), findsOneWidget);
      expect(find.text('Entrar como Sofía'), findsOneWidget);
      expect(find.text('Entrar como Carlos'), findsOneWidget);
      expect(
        find.text('Simular paso por Registro Web / Partner'),
        findsOneWidget,
      );

      await tester.tap(find.text('Entrar como Carlos'));
      await tester.pumpAndSettle();

      expect(AuthService().currentUser.role, UserRole.owner);
      expect(find.text('Mis Negocios'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Simulating partner registration from the sheet elevates a client to owner',
    (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(AuthService().currentUser.role, UserRole.client);

      await tester.tap(find.text('Dev Mode'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Simular paso por Registro Web / Partner'),
      );
      await tester.pumpAndSettle();

      expect(AuthService().currentUser.role, UserRole.owner);
      expect(find.text('Mis Negocios'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
