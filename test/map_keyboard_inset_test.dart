import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_bottom_dock.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Regresión del mapa con el teclado abierto.
///
/// Al escribir en la búsqueda, el dock (píldora de recomendaciones, botón
/// de ubicación, FAB del asistente y carrusel) se despegaba del borde
/// inferior y quedaba flotando a media pantalla sobre el teclado.
///
/// La causa no estaba en el mapa sino encima: el `Scaffold` del shell
/// resolvía el inset del teclado, lo que (a) encogía el área del mapa, con
/// lo que su `bottom: 0` dejaba de ser el borde de la pantalla, y (b)
/// envolvía a sus hijos en `MediaQuery.removeViewInsets(removeBottom:
/// true)`, así que el guard que debía apartar el dock leía siempre
/// `viewInsets.bottom == 0` y nunca se cumplía.
///
/// Se cubre con dos piezas que se necesitan mutuamente:
///
/// - el shell de estos tests imita al de `MainLayout` **ya arreglado**
///   (`resizeToAvoidBottomInset: false`), y verifica que con esa base el
///   mapa aparte el dock al abrirse el teclado y lo devuelva al cerrarse;
/// - el último test monta el `MainLayout` real y fija esa configuración,
///   que es la que hace llegar el inset. Sin él, alguien podría volver a
///   poner el shell a resolver el teclado y los dos primeros seguirían en
///   verde contra su propio andamiaje.
///
/// Se evaluó y descartó decidirlo por el foco del campo de búsqueda: el
/// botón atrás de Android cierra el teclado sin soltar el foco, con lo que
/// el dock quedaba escondido sobre un mapa sin controles.
void main() {
  const keyboardHeight = 320.0;
  const screenSize = Size(390, 844);

  setUpAll(() async {
    // Mismo arranque que el resto de los widget tests: AuthService toca
    // `Supabase.instance` de forma síncrona (ver CLAUDE.md).
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpMap(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screenSize;
    await tester.pumpWidget(
      const MaterialApp(
        // Anidado dentro de otro `Scaffold`, como vive en la app bajo el
        // shell de `MainLayout`: montado suelto el mapa leía el inset real
        // y el bug no aparecía nunca. Este shell copia la configuración del
        // real —incluido `resizeToAvoidBottomInset: false`, que es lo que
        // deja pasar el inset— y el último test se encarga de que
        // `MainLayout` siga siendo así.
        home: Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: MapScreen(),
          bottomNavigationBar: SizedBox(height: 64),
        ),
      ),
    );
    // No `pumpAndSettle`: el mapa tiene animaciones que no terminan solas.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Abre el teclado como lo haría el sistema: foco en el campo de búsqueda
  /// más el inset de la ventana.
  Future<void> openKeyboard(WidgetTester tester) async {
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Desmonta y deja correr el reloj: el mapa cierra su canal de Realtime en
  /// `dispose()` y ese cierre agenda un timer que, sin drenar, haría fallar
  /// el test por "pending timers".
  Future<void> disposeMap(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  }

  testWidgets('el dock se aparta al escribir en la búsqueda', (tester) async {
    addTearDown(tester.view.reset);
    await pumpMap(tester);
    expect(find.byType(MapBottomDock), findsOneWidget);

    await openKeyboard(tester);

    expect(
      find.byType(MapBottomDock),
      findsNothing,
      reason:
          'Con el teclado abierto el dock debe retirarse; si sigue montado '
          'queda flotando a media pantalla, encima del teclado.',
    );
    expect(tester.takeException(), isNull);

    await disposeMap(tester);
  });

  testWidgets(
    'el dock vuelve al cerrar el teclado aunque el campo siga enfocado',
    (tester) async {
      addTearDown(tester.view.reset);
      await pumpMap(tester);
      await openKeyboard(tester);

      // El botón atrás de Android cierra el teclado pero **no** suelta el
      // foco. Por eso se baja solo el inset: visto en el teléfono, una
      // versión de este guard basada en el foco dejaba el dock escondido
      // sobre un mapa sin controles justo acá.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        FocusManager.instance.primaryFocus?.hasFocus,
        isTrue,
        reason: 'El caso que se quiere cubrir es con el foco todavía puesto.',
      );

      expect(find.byType(MapBottomDock), findsOneWidget);
      expect(
        tester.getRect(find.byType(MapBottomDock)).bottom,
        screenSize.height,
        reason: 'El dock se ancla al borde real de la pantalla, no más arriba.',
      );
      expect(tester.takeException(), isNull);

      await disposeMap(tester);
    },
  );

  testWidgets('el shell de MainLayout no resuelve el teclado por sus tabs', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screenSize;
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const MainLayout()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Complementa al foco: aunque el dock ya no se descoloca, dejar que el
    // shell encoja el `PageView` aplastaría el mapa detrás del teclado.
    // Cada tab trae su propio `Scaffold`, así que la decisión es suya.
    final shells = tester
        .widgetList<Scaffold>(find.byType(Scaffold))
        .where((s) => s.resizeToAvoidBottomInset == false);
    expect(
      shells,
      isNotEmpty,
      reason:
          'El Scaffold de MainLayout debe declarar '
          'resizeToAvoidBottomInset: false y delegar el teclado en cada tab.',
    );

    await disposeMap(tester);
  });
}
