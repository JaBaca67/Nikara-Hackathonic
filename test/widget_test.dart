import 'package:flutter_test/flutter_test.dart';
// ¡Actualizamos la ruta para que busque MyApp en app.dart!
import 'package:nikara_app/app.dart'; 

void main() {
  testWidgets('Prueba de humo para la pantalla de Login', (WidgetTester tester) async {
    // Construimos nuestra app y disparamos un frame.
    await tester.pumpWidget(const MyApp());

    // Verificamos que nuestra pantalla de Login cargó correctamente 
    // buscando los textos de tu diseño.
    expect(find.text('Nikara'), findsOneWidget);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    
    // Verificamos que el contador viejo ya no existe
    expect(find.text('0'), findsNothing);
  });
}