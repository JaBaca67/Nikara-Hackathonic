import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ¡Actualizamos la ruta para que busque MyApp en app.dart!
import 'package:nikara_app/app.dart';

void main() {
  setUp(() {
    // MyApp routes through a _SessionGate that reads UserSessionService
    // (SharedPreferences) before deciding Login vs. MainLayout — without a
    // mocked store this hits a real platform channel that doesn't exist in
    // the test environment.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Prueba de humo para la pantalla de Login', (WidgetTester tester) async {
    // Construimos nuestra app y esperamos a que _SessionGate resuelva su
    // lectura async (isLoggedIn == false con prefs vacías) y navegue a
    // LoginScreen.
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
