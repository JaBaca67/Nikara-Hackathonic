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
}
