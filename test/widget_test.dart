import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ¡Actualizamos la ruta para que busque MyApp en app.dart!
import 'package:nikara_app/app.dart';

void main() {
  setUp(() {
    // Some services still read local SharedPreferences state (favorites,
    // avatar cache) — without a mocked store this hits a real platform
    // channel that doesn't exist in the test environment.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Prueba de humo para la pantalla de Login', (WidgetTester tester) async {
    // MyApp reads AuthService().isLoggedIn synchronously (no Supabase
    // session persisted in the test environment), so it renders LoginScreen
    // directly.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

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
