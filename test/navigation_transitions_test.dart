import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La app no usa `MaterialPageRoute`: todas las navegaciones pasan por los
/// helpers de `app_page_transition.dart`, que eligen el movimiento según el
/// significado de la navegación y respetan "Eliminar animaciones" del
/// sistema. Un `MaterialPageRoute` nuevo se cuela sin romper nada ni dar
/// warning — por eso la regla se verifica acá y no en el linter.
void main() {
  test('ninguna pantalla usa MaterialPageRoute directamente', () {
    final infractores = <String>[];

    for (final entidad in Directory('lib').listSync(recursive: true)) {
      if (entidad is! File || !entidad.path.endsWith('.dart')) continue;
      // El propio helper lo nombra en su documentación.
      if (entidad.path.endsWith('app_page_transition.dart')) continue;

      final lineas = entidad.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (lineas[i].contains('MaterialPageRoute')) {
          infractores.add('${entidad.path.replaceAll(r'\', '/')}:${i + 1}');
        }
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Usar pushSharedAxis / pushSharedAxisReplacement / '
          'pushFadeThroughAndRemoveUntil en vez de MaterialPageRoute.\n'
          'Ver CLAUDE.md > Sistema de diseño > Movimiento.',
    );
  });
}
