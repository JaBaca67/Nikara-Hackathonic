import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/shared/widgets/app_confirm_dialog.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/theme/app_theme.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

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

  group('AppSnackbar', () {
    Future<void> open(
      WidgetTester tester,
      void Function(BuildContext) show, {
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => show(context),
              child: const Text('go'),
            ),
          ),
          disableAnimations: disableAnimations,
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
    }

    testWidgets('cada tipo usa su ícono y su color de token', (tester) async {
      final cases = <(void Function(BuildContext), IconData, Color)>[
        (
          (c) => AppSnackbar.showSuccess(c, 'Local agregado exitosamente'),
          Icons.check_circle_rounded,
          AppColors.success,
        ),
        (
          (c) => AppSnackbar.showError(c, 'No se pudo guardar'),
          Icons.error_rounded,
          AppColors.error,
        ),
        (
          (c) => AppSnackbar.showInfo(c, 'Próximamente'),
          Icons.info_rounded,
          AppColors.oliveText,
        ),
      ];
      for (final (show, icon, color) in cases) {
        await open(tester, show);
        await tester.pump(const Duration(milliseconds: 300));
        final iconWidget = tester.widget<Icon>(find.byIcon(icon));
        expect(iconWidget.color, color);
        expect(iconWidget.size, 24);
      }
    });

    testWidgets('el error dura más que el éxito', (tester) async {
      await open(tester, (c) => AppSnackbar.showSuccess(c, 'Listo'));
      final success = tester.widget<SnackBar>(find.byType(SnackBar)).duration;
      await open(tester, (c) => AppSnackbar.showError(c, 'Falló'));
      final error = tester.widget<SnackBar>(find.byType(SnackBar)).duration;
      expect(error, greaterThan(success));
    });

    testWidgets('con movimiento reducido aparece sin animación', (
      tester,
    ) async {
      await open(
        tester,
        (c) => AppSnackbar.showSuccess(c, 'Listo'),
        disableAnimations: true,
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Listo'), findsOneWidget);
    });
  });

  group('AppConfirmDialog', () {
    Future<bool?> run(WidgetTester tester, String tapLabel) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await AppConfirmDialog.show(
                  context,
                  title: '¿Salir sin guardar?',
                  message: 'Perderás el progreso de tu ruta.',
                  confirmLabel: 'Salir',
                  cancelLabel: 'Continuar',
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tester.tap(find.text(tapLabel));
      await tester.pump(const Duration(milliseconds: 400));
      return result;
    }

    testWidgets('confirmar devuelve true', (tester) async {
      expect(await run(tester, 'Salir'), isTrue);
    });

    testWidgets('cancelar devuelve false', (tester) async {
      expect(await run(tester, 'Continuar'), isFalse);
    });

    testWidgets('tocar fuera no cierra el diálogo', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => AppConfirmDialog.show(
                context,
                title: 'Título',
                message: 'Mensaje',
                confirmLabel: 'Sí',
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Título'), findsOneWidget);
    });
  });

  group('AppLoadingButton', () {
    testWidgets('ignora el segundo toque mientras guarda', (tester) async {
      final completer = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          AppLoadingButton(
            label: 'Guardar',
            onPressed: () {
              calls++;
              return completer.future;
            },
          ),
        ),
      );

      await tester.tap(find.text('Guardar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);

      completer.complete();
      // Un frame para que corra el setState y otro para que el
      // AnimatedSwitcher complete su transición.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('isLoading externo deshabilita el botón', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          AppLoadingButton(
            label: 'Guardar',
            isLoading: true,
            onPressed: () => calls++,
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(calls, 0);
    });
  });

  group('AppBusyOverlay', () {
    testWidgets('bloquea toques solo cuando está visible', (tester) async {
      var taps = 0;
      Widget build(bool visible) => _host(
        AppBusyOverlay(
          visible: visible,
          message: 'Guardando…',
          child: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('debajo'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(false));
      await tester.tap(find.text('debajo'));
      expect(taps, 1);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('debajo'), warnIfMissed: false);
      expect(taps, 1);
      expect(find.text('Guardando…'), findsOneWidget);
    });
  });

  group('AppSnackbar: animación y acción', () {
    Future<BuildContext> open(
      WidgetTester tester,
      void Function(BuildContext) show, {
      bool disableAnimations = false,
    }) async {
      late BuildContext captured;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              captured = context;
              return TextButton(
                onPressed: () => show(context),
                child: const Text('go'),
              );
            },
          ),
          disableAnimations: disableAnimations,
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      return captured;
    }

    final iconScaleFinder = find.byWidgetPredicate(
      (w) => w is Transform && w.child is Icon,
    );
    double iconScale(WidgetTester tester) =>
        tester.widget<Transform>(iconScaleFinder).transform.storage[0];

    testWidgets('el ícono se asienta de 0.8 a 1.0 sin sobrepasar', (
      tester,
    ) async {
      await open(tester, (c) => AppSnackbar.showSuccess(c, 'Listo'));
      expect(iconScale(tester), closeTo(0.8, 0.01));

      var maxScale = 0.0;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final scale = iconScale(tester);
        if (scale > maxScale) maxScale = scale;
      }
      expect(iconScale(tester), closeTo(1.0, 0.001));
      expect(maxScale, lessThanOrEqualTo(1.0));
    });

    testWidgets('con movimiento reducido no escala y aparece al instante', (
      tester,
    ) async {
      await open(
        tester,
        (c) => AppSnackbar.showSuccess(c, 'Listo'),
        disableAnimations: true,
      );
      expect(iconScaleFinder, findsNothing);
      expect(find.text('Listo'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('sin acción se ve igual que antes: ícono, espacio y texto', (
      tester,
    ) async {
      await open(tester, (c) => AppSnackbar.showError(c, 'Falló'));
      await tester.pump(const Duration(milliseconds: 300));

      final snackbar = find.byType(SnackBar);
      expect(
        find.descendant(of: snackbar, matching: find.byType(TextButton)),
        findsNothing,
      );
      // El Row de la alerta es el que abre con el ícono (el SnackBar nativo
      // trae Rows internos propios).
      final row = tester.widget<Row>(
        find.descendant(
          of: snackbar,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Row &&
                w.children.isNotEmpty &&
                w.children.first.runtimeType.toString() == '_SettlingIcon',
          ),
        ),
      );
      expect(row.children.length, 3);
      expect(tester.widget<SnackBar>(snackbar).duration.inSeconds, 5);
    });

    testWidgets('con acción: botón en el color del tipo y tipografía de app', (
      tester,
    ) async {
      var calls = 0;
      await open(
        tester,
        (c) => AppSnackbar.showError(
          c,
          'Sin conexión',
          actionLabel: 'Reintentar',
          onAction: () => calls++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final button = tester.widget<TextButton>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.style!.foregroundColor!.resolve({}), AppColors.error);
      expect(button.style!.minimumSize!.resolve({})!.height, 48);
      final label = tester.widget<Text>(find.text('Reintentar'));
      expect(label.style!.fontWeight, FontWeight.w700);
      expect(calls, 0);
    });

    testWidgets('pulsar la acción la ejecuta una vez y cierra la alerta', (
      tester,
    ) async {
      var calls = 0;
      await open(
        tester,
        (c) => AppSnackbar.showSuccess(
          c,
          '¡Ruta guardada!',
          actionLabel: 'Ver ruta',
          onAction: () => calls++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Ver ruta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('cada tipo pinta la acción con su propio color', (
      tester,
    ) async {
      final cases = <(void Function(BuildContext), Color)>[
        (
          (c) => AppSnackbar.showSuccess(
            c,
            'Ok',
            actionLabel: 'Ver',
            onAction: () {},
          ),
          AppColors.success,
        ),
        (
          (c) => AppSnackbar.showInfo(
            c,
            'Aviso',
            actionLabel: 'Ver',
            onAction: () {},
          ),
          AppColors.oliveText,
        ),
      ];
      for (final (show, color) in cases) {
        await open(tester, show);
        await tester.pump(const Duration(milliseconds: 300));
        final button = tester.widget<TextButton>(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(TextButton),
          ),
        );
        expect(button.style!.foregroundColor!.resolve({}), color);
      }
    });

    testWidgets('con acción la alerta dura más, para poder pulsarla', (
      tester,
    ) async {
      await open(tester, (c) => AppSnackbar.showError(c, 'Falló'));
      final plain = tester.widget<SnackBar>(find.byType(SnackBar)).duration;
      await open(
        tester,
        (c) => AppSnackbar.showError(
          c,
          'Falló',
          actionLabel: 'Reintentar',
          onAction: () {},
        ),
      );
      final withAction = tester
          .widget<SnackBar>(find.byType(SnackBar))
          .duration;
      expect(withAction, greaterThan(plain));
    });

    testWidgets('la salida dura menos que la entrada (≤ 200 ms)', (
      tester,
    ) async {
      final context = await open(
        tester,
        (c) => AppSnackbar.showSuccess(c, 'Listo'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsOneWidget);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('AppConfirmDialog: animación', () {
    Future<void> open(
      WidgetTester tester, {
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => AppConfirmDialog.show(
                context,
                title: 'Título',
                message: 'Mensaje',
                confirmLabel: 'Sí',
              ),
              child: const Text('abrir'),
            ),
          ),
          disableAnimations: disableAnimations,
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
    }

    final scaleFinder = find.byKey(const ValueKey('confirm-dialog-scale'));

    testWidgets('entra con escala de 0.95 a 1.0 sin sobrepasar', (
      tester,
    ) async {
      await open(tester);
      await tester.pump(const Duration(milliseconds: 20));
      final start = tester.widget<ScaleTransition>(scaleFinder).scale.value;
      expect(start, greaterThanOrEqualTo(0.95));
      expect(start, lessThan(1.0));

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(
          tester.widget<ScaleTransition>(scaleFinder).scale.value,
          lessThanOrEqualTo(1.0),
        );
      }
      expect(tester.widget<ScaleTransition>(scaleFinder).scale.value, 1.0);
    });

    testWidgets('con movimiento reducido aparece sin escala ni espera', (
      tester,
    ) async {
      await open(tester, disableAnimations: true);
      await tester.pump(const Duration(milliseconds: 20));
      expect(scaleFinder, findsNothing);
      expect(find.text('Título'), findsOneWidget);
    });

    testWidgets('la salida dura menos que la entrada (≤ 200 ms)', (
      tester,
    ) async {
      await open(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Título'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      // Un frame más para que la ruta ya descartada salga del árbol.
      await tester.pump();
      expect(find.text('Título'), findsNothing);
    });
  });
}
