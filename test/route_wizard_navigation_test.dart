import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/routes/presentation/screens/create_route_wizard_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Abre el wizard encima de una pantalla "Rutas" para poder comprobar si
  /// se volvió a ella.
  Future<void> openWizard(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateRouteWizardScreen(),
                  ),
                ),
                child: const Text('Rutas'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Rutas'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 500));

  Future<void> goToStepTwo(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Fin de semana en Granada');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await settle(tester);
    expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
  }

  testWidgets('no hay botón "Salir" en la cabecera', (tester) async {
    await openWizard(tester);
    expect(find.text('Salir'), findsNothing);
  });

  testWidgets('paso 1: la flecha pide confirmar y "Continuar" se queda', (
    tester,
  ) async {
    await openWizard(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    expect(find.text('Perderás el progreso de tu ruta.'), findsOneWidget);

    // "Continuar" también es el botón del pie del wizard: se busca dentro del
    // diálogo.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Continuar'),
      ),
    );
    await settle(tester);
    expect(find.text('¿Salir sin guardar?'), findsNothing);
    expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('paso 1: confirmar "Salir" vuelve a Rutas', (tester) async {
    await openWizard(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    await tester.tap(find.text('Salir'));
    await settle(tester);
    await settle(tester);

    expect(find.byType(CreateRouteWizardScreen), findsNothing);
    expect(find.text('Rutas'), findsOneWidget);
  });

  testWidgets('el atrás del sistema hace lo mismo que la flecha', (
    tester,
  ) async {
    await openWizard(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    expect(find.byType(CreateRouteWizardScreen), findsOneWidget);
  });

  testWidgets('paso 2: "Retroceder" vuelve al paso 1 conservando el nombre', (
    tester,
  ) async {
    await openWizard(tester);
    await goToStepTwo(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.text('¿Qué quieres hacer?'), findsOneWidget);

    await tester.tap(find.text('Retroceder'));
    await settle(tester);

    expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
    expect(find.text('Fin de semana en Granada'), findsOneWidget);
  });

  testWidgets('paso 2: "Salir" avisa de la pérdida y vuelve a Rutas', (
    tester,
  ) async {
    await openWizard(tester);
    await goToStepTwo(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.textContaining('se pierde todo el progreso'), findsOneWidget);

    await tester.tap(find.text('Salir'));
    await settle(tester);
    await settle(tester);
    expect(find.byType(CreateRouteWizardScreen), findsNothing);
  });

  testWidgets('cerrar el diálogo de pasos 2+ con atrás no retrocede', (
    tester,
  ) async {
    await openWizard(tester);
    await goToStepTwo(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    // El atrás del sistema cierra el diálogo, no el wizard.
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('¿Qué quieres hacer?'), findsNothing);
    expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
  });

  /// Espera al catálogo del paso 2 (corre fuera del reloj falso) y agrega el
  /// primer lugar de la lista.
  Future<void> addFirstStop(WidgetTester tester) async {
    for (
      var i = 0;
      i < 20 && find.text('Agregar a ruta').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Agregar a ruta'), findsWidgets);
    await tester.tap(find.text('Agregar a ruta').first);
    await settle(tester);
  }

  testWidgets('paso 1: Continuar siempre activo; sin nombre muestra el error', (
    tester,
  ) async {
    await openWizard(tester);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    expect(find.textContaining('mínimo 3 letras'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await settle(tester);

    expect(
      find.text('Ponle un nombre a tu ruta (mínimo 3 letras).'),
      findsOneWidget,
    );
    expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('paso 1: un nombre de 2 letras sigue siendo inválido', (
    tester,
  ) async {
    await openWizard(tester);
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await settle(tester);

    expect(find.textContaining('mínimo 3 letras'), findsOneWidget);
    expect(find.textContaining('Paso 1 de 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(find.textContaining('mínimo 3 letras'), findsNothing);
  });

  testWidgets('paso 2: sin ningún lugar avisa y no avanza', (tester) async {
    await openWizard(tester);
    await goToStepTwo(tester);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Agrega al menos un lugar a tu ruta para continuar.'),
      findsOneWidget,
    );
    expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
  });

  testWidgets('paso 2: si el catálogo falla se puede reintentar', (
    tester,
  ) async {
    await openWizard(tester);
    await goToStepTwo(tester);
    for (var i = 0; i < 20 && find.text('Reintentar').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    // Mientras vuelve a cargar se muestra el indicador de sección.
    expect(find.text('Cargando lugares…'), findsOneWidget);

    for (
      var i = 0;
      i < 20 && find.text('Cargando lugares…').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Cargando lugares…'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('zonas tocables de al menos 48dp', (tester) async {
    await openWizard(tester);
    final back = find.ancestor(
      of: find.byIcon(Icons.arrow_back),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(back.first).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(back.first).width, greaterThanOrEqualTo(48));

    await goToStepTwo(tester);
    await addFirstStop(tester);
    final add = find.ancestor(
      of: find.text('Agregado').first,
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(add.first).height, greaterThanOrEqualTo(48));
  });

  testWidgets('paso 3: los días vacíos solo avisan, no bloquean', (
    tester,
  ) async {
    await openWizard(tester);
    await goToStepTwo(tester);
    await addFirstStop(tester);
    // Un solo lugar y 1 día: para tener un día vacío se aumenta la duración
    // desde el paso 1.
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('Retroceder'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await settle(tester);
    await tester.tap(find.text('Continuar'));
    await settle(tester);
    await addFirstStop(tester);
    await tester.tap(find.byType(FilledButton).last);
    await settle(tester);

    expect(find.textContaining('Paso 3 de 3'), findsOneWidget);
    expect(find.textContaining('Puedes guardar la ruta así'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save.onPressed, isNotNull);
  });
}
