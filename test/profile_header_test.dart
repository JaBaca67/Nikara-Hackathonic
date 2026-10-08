import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Cabecera del Perfil de turista tal como la arma `ProfileScreen`: cambiar de
/// cuenta, vista del perfil público y Ajustes.
Widget _header({required List<VoidCallback> taps, int buttons = 3}) {
  const icons = [
    (Icons.switch_account_outlined, 'Cambiar de cuenta'),
    (Icons.visibility_outlined, 'Ver mi perfil público'),
    (Icons.settings_outlined, 'Ajustes'),
  ];
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProfileHeaderShell(
          actions: [
            for (var i = 0; i < buttons; i++)
              ProfileHeaderIconButton(
                icon: icons[i].$1,
                label: icons[i].$2,
                onTap: taps[i],
              ),
          ],
          avatar: const SizedBox(width: 72, height: 72),
          faceControl: FaceSelectorControl(
            name: 'Ana López',
            kindLabel: 'Turista',
            onTap: () {},
          ),
          stats: const [
            ProfileStat(value: '1', label: 'Viajes'),
            ProfileStat(value: '2', label: 'Insignias'),
            ProfileStat(value: '3', label: 'Puntos'),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final noop = <VoidCallback>[() {}, () {}, () {}, () {}, () {}];

  Future<void> pumpAt(WidgetTester tester, Size size, Widget app) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
    await tester.pump();
  }

  group('botones de la cabecera del Perfil', () {
    testWidgets('cada uno mide al menos 48dp', (tester) async {
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      for (final label in [
        'Cambiar de cuenta',
        'Ajustes',
        'Ver mi perfil público',
      ]) {
        final size = tester.getSize(find.byTooltip(label));
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets(
      'Ver mi perfil público y Ajustes tienen acciones independientes',
      (tester) async {
        var editTaps = 0;
        var settingsTaps = 0;
        await pumpAt(
          tester,
          const Size(390, 800),
          _header(
            taps: [() {}, () => editTaps++, () => settingsTaps++, () {}, () {}],
          ),
        );

        expect(find.byTooltip('Ajustes'), findsOneWidget);
        expect(find.byTooltip('Ver mi perfil público'), findsOneWidget);
        await tester.tap(find.byTooltip('Ver mi perfil público'));
        expect(editTaps, 1);
        expect(settingsTaps, 0);

        await tester.tap(find.byTooltip('Ajustes'));
        expect(settingsTaps, 1);
        expect(editTaps, 1);
      },
    );

    testWidgets('tienen etiqueta para lectores de pantalla en español', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      expect(find.bySemanticsLabel('Ajustes'), findsOneWidget);
      expect(find.bySemanticsLabel('Cambiar de cuenta'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sin hueco: quedan contiguos, centrados y junto al margen', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      final rects = [
        for (final label in [
          'Cambiar de cuenta',
          'Ver mi perfil público',
          'Ajustes',
        ])
          tester.getRect(find.byTooltip(label)),
      ];
      // Contiguos: cada caja empieza donde termina la anterior (el aire entre
      // círculos viene de las cajas de 48, no de un separador aparte).
      expect(rects[1].left, closeTo(rects[0].right, 0.01));
      expect(rects[2].left, closeTo(rects[1].right, 0.01));
      // Mismo eje vertical.
      expect(rects[1].center.dy, closeTo(rects[0].center.dy, 0.01));
      expect(rects[2].center.dy, closeTo(rects[0].center.dy, 0.01));
      // Pegados al margen derecho (16 de relleno), sin quedar fuera.
      expect(rects.last.right, closeTo(390 - 16, 0.01));
      // Y alineados con el título "Perfil" de la misma fila.
      final title = tester.getRect(find.text('Perfil'));
      expect(rects[1].center.dy, closeTo(title.center.dy, 1));
    });

    testWidgets('la fila del título conserva su altura de antes (64dp)', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      final shellTop = tester.getTopLeft(find.byType(ProfileHeaderShell)).dy;
      final button = tester.getRect(find.byTooltip('Ajustes'));
      // 8 de relleno arriba + 48 del botón + 8 abajo = 16 + 36 + 12 de antes.
      expect(button.top - shellTop, 8);
      expect(button.bottom - shellTop, 56);
    });

    testWidgets('no desborda con los tres botones en 360dp', (tester) async {
      await pumpAt(tester, const Size(360, 800), _header(taps: noop));

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byTooltip('Ajustes')).right,
        lessThanOrEqualTo(360),
      );
    });

    testWidgets('los tres botones caben en el ancho disponible', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      final first = tester.getRect(find.byTooltip('Cambiar de cuenta'));
      final last = tester.getRect(find.byTooltip('Ajustes'));
      final width = last.right - first.left;
      expect(width, 3 * ProfileHeaderIconButton.touchTarget);
      expect(width, lessThanOrEqualTo(390 - 36 - 80));
    });
  });
}
