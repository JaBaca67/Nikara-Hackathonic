import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_theme.dart';
import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// Envuelve [child] declarando el ajuste de accesibilidad "Eliminar
/// animaciones" del sistema.
Widget _withDisableAnimations(Widget child, {required bool disabled}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disabled),
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
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

  group('AppMotion.reduced / respect', () {
    testWidgets('leen el ajuste del sistema', (tester) async {
      late bool reducido;
      late Duration duracion;

      await tester.pumpWidget(
        _withDisableAnimations(
          Builder(
            builder: (context) {
              reducido = AppMotion.reduced(context);
              duracion = AppMotion.respect(context, AppMotion.largeDuration);
              return const SizedBox.shrink();
            },
          ),
          disabled: true,
        ),
      );

      expect(reducido, isTrue);
      expect(duracion, Duration.zero);
    });

    testWidgets('sin el ajuste devuelven la duración original', (tester) async {
      late Duration duracion;

      await tester.pumpWidget(
        _withDisableAnimations(
          Builder(
            builder: (context) {
              duracion = AppMotion.respect(context, AppMotion.largeDuration);
              return const SizedBox.shrink();
            },
          ),
          disabled: false,
        ),
      );

      expect(duracion, AppMotion.largeDuration);
    });
  });

  group('AuroraBackgroundWidget', () {
    // `pumpAndSettle` es la prueba observable de que el ticker se detuvo: con
    // el ciclo infinito corriendo nunca termina (por eso el resto de la suite
    // usa `pump()` con duración explícita en pantallas con aurora).
    testWidgets('detiene el ciclo cuando el sistema reduce el movimiento', (
      tester,
    ) async {
      await tester.pumpWidget(
        _withDisableAnimations(const AuroraBackgroundWidget(), disabled: true),
      );

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('mantiene el ciclo corriendo por defecto', (tester) async {
      await tester.pumpWidget(
        _withDisableAnimations(const AuroraBackgroundWidget(), disabled: false),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
