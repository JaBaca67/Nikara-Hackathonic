import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/core/utils/validators.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Los mensajes de `validators.dart` llegan a 67 caracteres, bastante más
/// largos que los validadores inline que reemplazaron. El default de Material
/// para `errorText` es **una sola línea**, así que en un contenedor angosto
/// (el diálogo "Editar perfil" de Ajustes mide ~260dp de contenido) el texto
/// se corta con ellipsis y el usuario pierde justo la parte que le dice qué
/// hacer: «Ese número no parece válido. Escríbel…» — visto en dispositivo el
/// 2026-10-05.
///
/// `overflow_audit_test.dart` no puede cubrir esto: un truncado por ellipsis
/// es el comportamiento *correcto* de `Text`, no un `RenderFlex overflow`, así
/// que no lanza ninguna excepción que un test pueda capturar. De ahí este
/// archivo, que fija la condición en el único punto que la gobierna.
void main() {
  // `AppTheme.lightTheme` resuelve tipografías vía google_fonts, que toca
  // ServicesBinding al construirse.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el tema deja a los mensajes de error usar más de una línea', () {
    final errorMaxLines =
        AppTheme.lightTheme.inputDecorationTheme.errorMaxLines;

    expect(
      errorMaxLines,
      isNotNull,
      reason:
          'Sin errorMaxLines en el tema cada InputDecoration cae en el default '
          'de Material (1 línea) y los mensajes largos se cortan.',
    );
    expect(
      errorMaxLines,
      greaterThanOrEqualTo(2),
      reason: 'Los mensajes de validators.dart no caben en una sola línea.',
    );
  });

  test('ningún mensaje de validación supera lo que caben dos líneas', () {
    // Dos líneas a ~34 caracteres cada una en el contenedor más angosto que
    // tiene la app (el diálogo de Ajustes). Si un mensaje nuevo pasa de aquí,
    // hay que acortarlo o revisar dónde se muestra — no subir el límite sin
    // mirarlo en pantalla.
    const maxLegible = 68;

    final mensajes = <String>[
      validateEmail('x')!,
      validatePhone('123')!,
      validateUsername('ab')!,
      validatePassword('abc')!,
    ];

    for (final mensaje in mensajes) {
      expect(
        mensaje.length,
        lessThanOrEqualTo(maxLegible),
        reason: 'Mensaje demasiado largo para dos líneas: "$mensaje"',
      );
    }
  });
}
