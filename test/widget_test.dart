import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    // AuthService touches Supabase.instance synchronously (even just to
    // check isLoggedIn), which throws an assertion error if Supabase was
    // never initialized — real credentials aren't needed, initialize()
    // only needs to complete its local setup for that assertion to pass.
    // Supabase.initialize() reaches for SharedPreferences internally
    // (GoTrue's local session storage), so the mock store has to exist
    // before initialize() runs, not just before each test.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    // Some services still read local SharedPreferences state (favorites,
    // avatar cache) — without a mocked store this hits a real platform
    // channel that doesn't exist in the test environment.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Prueba de humo para la pantalla de Login', (
    WidgetTester tester,
  ) async {
    // LoginScreen directly (not MyApp/SplashTransitionScreen) — this is a
    // smoke test for the Login screen itself, not the app's boot sequence.
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verificamos que nuestra pantalla de Login cargó correctamente
    // buscando los textos de tu diseño.
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(
      find.text('Inicia sesión para continuar tu aventura'),
      findsOneWidget,
    );

    // Verificamos que el contador viejo ya no existe
    expect(find.text('0'), findsNothing);
  });
}
