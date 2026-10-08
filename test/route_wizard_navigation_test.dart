import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/routes/presentation/screens/create_route_wizard_screen.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _kBackTooltip = 'Volver al paso anterior';
const _kExitTooltip = 'Salir de crear ruta';

void main() {
  bool failCatalog = false;
  Completer<void>? catalogGate;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: MockClient((request) async {
        if (catalogGate != null) await catalogGate!.future;
        return http.Response(
          jsonEncode(
            failCatalog ? {'code': '42501', 'message': 'fallo simulado'} : [],
          ),
          failCatalog ? 403 : 200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  setUp(() {
    failCatalog = false;
    catalogGate = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) async =>
              call.method == 'isLocationServiceEnabled' ? false : null,
        );
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

  /// Botón principal del pie ("Continuar" / "Guardar ruta").
  Future<void> tapPrimary(WidgetTester tester) async {
    await tester.tap(find.byType(AppLoadingButton));
    await settle(tester);
  }

  /// Botón de la alerta abierta (el texto "Continuar" también existe en el
  /// pie del wizard, así que se busca dentro del diálogo).
  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  Future<void> tapDialog(WidgetTester tester, String label) async {
    await tester.tap(dialogButton(label));
    await settle(tester);
    await settle(tester);
  }

  Future<void> goToStepTwo(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Fin de semana en Granada');
    await tester.pump();
    await tapPrimary(tester);
    expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
  }

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

  Future<void> goToStepThree(WidgetTester tester) async {
    await goToStepTwo(tester);
    await addFirstStop(tester);
    await tapPrimary(tester);
    expect(find.textContaining('Paso 3 de 3'), findsOneWidget);
  }

  Finder headerButton(String tooltip) => find.byTooltip(tooltip);

  group('paso 1', () {
    testWidgets('solo tiene la flecha: no hay botón Salir ni X', (
      tester,
    ) async {
      await openWizard(tester);
      expect(find.text('Salir'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(headerButton(_kExitTooltip), findsOneWidget);
      expect(headerButton(_kBackTooltip), findsNothing);
    });

    testWidgets('la flecha pregunta y "Continuar" se queda', (tester) async {
      await openWizard(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);

      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      expect(find.text('Perderás el progreso de tu ruta.'), findsOneWidget);

      await tapDialog(tester, 'Continuar');
      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
    });

    testWidgets('confirmar "Salir" vuelve a Rutas', (tester) async {
      await openWizard(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      await tapDialog(tester, 'Salir');

      expect(find.byType(CreateRouteWizardScreen), findsNothing);
      expect(find.text('Rutas'), findsOneWidget);
    });

    testWidgets('el atrás del sistema hace lo mismo que su flecha', (
      tester,
    ) async {
      await openWizard(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      expect(find.byType(CreateRouteWizardScreen), findsOneWidget);

      await tapDialog(tester, 'Salir');
      expect(find.byType(CreateRouteWizardScreen), findsNothing);
    });

    testWidgets('tocar fuera de la alerta deja al usuario donde está', (
      tester,
    ) async {
      await openWizard(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      await tester.tapAt(const Offset(2, 2));
      await settle(tester);

      expect(find.byType(CreateRouteWizardScreen), findsOneWidget);
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
    });

    testWidgets('el atrás del sistema sobre la alerta cierra solo la alerta', (
      tester,
    ) async {
      await openWizard(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await settle(tester);

      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.byType(CreateRouteWizardScreen), findsOneWidget);
    });
  });

  group('pasos 2 y 3: cabecera con dos botones', () {
    testWidgets('hay flecha y X, cada uno con su tooltip', (tester) async {
      await openWizard(tester);
      await goToStepTwo(tester);

      expect(headerButton(_kBackTooltip), findsOneWidget);
      expect(headerButton(_kExitTooltip), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('ambos botones miden al menos 48dp', (tester) async {
      await openWizard(tester);
      await goToStepTwo(tester);

      for (final tooltip in [_kBackTooltip, _kExitTooltip]) {
        final size = tester.getSize(headerButton(tooltip));
        expect(size.width, greaterThanOrEqualTo(48), reason: tooltip);
        expect(size.height, greaterThanOrEqualTo(48), reason: tooltip);
      }
    });

    testWidgets('flecha sin cambios en el paso retrocede directo', (
      tester,
    ) async {
      await openWizard(tester);
      await goToStepTwo(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Fin de semana en Granada'), findsOneWidget);
    });

    testWidgets('flecha con cambios pregunta; "Cancelar" se queda', (
      tester,
    ) async {
      await openWizard(tester);
      await goToStepTwo(tester);
      await addFirstStop(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);

      expect(find.text('¿Volver al paso anterior?'), findsOneWidget);
      expect(
        find.text(
          'Perderás lo que editaste en este paso. Lo del paso anterior se '
          'conserva.',
        ),
        findsOneWidget,
      );

      await tapDialog(tester, 'Cancelar');
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Agregado'), findsOneWidget);
    });

    testWidgets('"Retroceder" descarta lo del paso y conserva el anterior', (
      tester,
    ) async {
      await openWizard(tester);
      await goToStepTwo(tester);
      await addFirstStop(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      await tapDialog(tester, 'Retroceder');

      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Fin de semana en Granada'), findsOneWidget);

      // Al volver a entrar al paso 2, lo agregado antes ya no está.
      await tapPrimary(tester);
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Agregado'), findsNothing);
    });

    testWidgets('el atrás del sistema hace lo mismo que la flecha', (
      tester,
    ) async {
      await openWizard(tester);
      await goToStepTwo(tester);

      // Sin cambios: directo al paso 1.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);

      // Con cambios: pregunta lo mismo que la flecha.
      await tapPrimary(tester);
      await addFirstStop(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('¿Volver al paso anterior?'), findsOneWidget);
    });

    testWidgets('la X siempre pregunta, aunque no haya cambios', (
      tester,
    ) async {
      await openWizard(tester);
      await goToStepTwo(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester);

      expect(find.text('¿Salir de crear ruta?'), findsOneWidget);
      expect(
        find.text('Perderás todo el progreso de tu ruta y volverás a Rutas.'),
        findsOneWidget,
      );

      await tapDialog(tester, 'Continuar');
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
    });

    testWidgets('la X confirmada vuelve a Rutas descartando todo', (
      tester,
    ) async {
      await openWizard(tester);
      await goToStepTwo(tester);
      await addFirstStop(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester);
      await tapDialog(tester, 'Salir');

      expect(find.byType(CreateRouteWizardScreen), findsNothing);
      expect(find.text('Rutas'), findsOneWidget);
    });

    testWidgets('paso 3: retrocede directo sin cambios y pregunta con ellos', (
      tester,
    ) async {
      await openWizard(tester);
      await goToStepThree(tester);

      // Sin cambios en el paso 3: directo al 2, conservando lo agregado.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Agregado'), findsOneWidget);

      // Con un cambio (quitar la parada): pregunta y "Retroceder" lo descarta.
      await tapPrimary(tester);
      await tester.tap(find.byTooltip('Quitar de la ruta'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.text('¿Volver al paso anterior?'), findsOneWidget);
      await tapDialog(tester, 'Retroceder');

      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Agregado'), findsOneWidget);
    });
  });

  group('validaciones', () {
    testWidgets('Continuar siempre activo; sin nombre muestra el error', (
      tester,
    ) async {
      await openWizard(tester);
      final button = tester.widget<AppLoadingButton>(
        find.byType(AppLoadingButton),
      );
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('mínimo 3 letras'), findsNothing);

      await tapPrimary(tester);

      expect(
        find.text('Ponle un nombre a tu ruta (mínimo 3 letras).'),
        findsOneWidget,
      );
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
    });

    testWidgets('un nombre de 2 letras sigue siendo inválido', (tester) async {
      await openWizard(tester);
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();
      await tapPrimary(tester);

      expect(find.textContaining('mínimo 3 letras'), findsOneWidget);
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.textContaining('mínimo 3 letras'), findsNothing);
    });

    testWidgets('el nombre se limita a 60 caracteres', (tester) async {
      await openWizard(tester);
      await tester.enterText(find.byType(TextField), 'a' * 80);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 60);
    });

    testWidgets('el texto del paso 1 tutea', (tester) async {
      await openWizard(tester);
      expect(find.textContaining('Elige un nombre'), findsOneWidget);
      expect(find.textContaining('Elegí'), findsNothing);
    });

    testWidgets('paso 2: sin ningún lugar avisa y no avanza', (tester) async {
      await openWizard(tester);
      await goToStepTwo(tester);

      await tester.tap(find.byType(AppLoadingButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Agrega al menos un lugar a tu ruta para continuar.'),
        findsOneWidget,
      );
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
    });

    testWidgets('paso 3: los días vacíos solo avisan, no bloquean', (
      tester,
    ) async {
      await openWizard(tester);
      // Dos días y un solo lugar: el día 2 queda vacío.
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await settle(tester);
      await goToStepThree(tester);

      expect(find.textContaining('Puedes guardar la ruta así'), findsOneWidget);
      final save = tester.widget<AppLoadingButton>(
        find.byType(AppLoadingButton),
      );
      expect(save.onPressed, isNotNull);
      expect(find.text('Guardar ruta'), findsOneWidget);
    });
  });

  testWidgets('paso 2: si el catálogo falla se puede reintentar', (
    tester,
  ) async {
    failCatalog = true;
    await openWizard(tester);
    await goToStepTwo(tester);
    for (var i = 0; i < 20 && find.text('Reintentar').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Reintentar'), findsOneWidget);

    failCatalog = false;
    catalogGate = Completer<void>();
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    // Mientras vuelve a cargar se muestra el indicador de sección.
    expect(find.text('Cargando lugares…'), findsOneWidget);
    catalogGate!.complete();

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
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('zonas tocables de al menos 48dp en los controles del wizard', (
    tester,
  ) async {
    await openWizard(tester);
    final back = tester.getSize(headerButton(_kExitTooltip));
    expect(back.width, greaterThanOrEqualTo(48));
    expect(back.height, greaterThanOrEqualTo(48));

    await goToStepTwo(tester);
    await addFirstStop(tester);
    final add = find.ancestor(
      of: find.text('Agregado').first,
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(add.first).height, greaterThanOrEqualTo(48));

    await tapPrimary(tester);
    for (final control in [
      find.byTooltip('Quitar de la ruta'),
      find.bySemanticsLabel('Subir parada'),
      find.bySemanticsLabel('Bajar parada'),
    ]) {
      final size = tester.getSize(control.first);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
