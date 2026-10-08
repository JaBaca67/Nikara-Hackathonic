import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Cabecera del Perfil de turista tal como la arma `ProfileScreen`: cambiar de
/// cuenta, Ajustes y compartir. El lápiz de "Editar perfil" se retiró porque
/// abría exactamente lo mismo que Ajustes.
Widget _header({required List<VoidCallback> taps, int buttons = 3}) {
  const icons = [
    (Icons.switch_account_outlined, 'Cambiar de cuenta'),
    (Icons.settings_outlined, 'Ajustes'),
    (Icons.ios_share, 'Compartir perfil'),
    (Icons.visibility_outlined, 'Ver como lo ven los viajeros'),
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
  final noop = <VoidCallback>[() {}, () {}, () {}, () {}];

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
        'Compartir perfil',
      ]) {
        final size = tester.getSize(find.byTooltip(label));
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('el botón que queda es "Ajustes" y ya no hay "Editar perfil"', (
      tester,
    ) async {
      var settingsTaps = 0;
      await pumpAt(
        tester,
        const Size(390, 800),
        _header(taps: [() {}, () => settingsTaps++, () {}]),
      );

      expect(find.byTooltip('Ajustes'), findsOneWidget);
      expect(find.byTooltip('Editar perfil'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      await tester.tap(find.byTooltip('Ajustes'));
      expect(settingsTaps, 1);
    });

    testWidgets('tienen etiqueta para lectores de pantalla en español', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      expect(find.bySemanticsLabel('Ajustes'), findsOneWidget);
      expect(find.bySemanticsLabel('Cambiar de cuenta'), findsOneWidget);
      expect(find.bySemanticsLabel('Compartir perfil'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sin hueco: quedan contiguos, centrados y junto al margen', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      final rects = [
        for (final label in [
          'Cambiar de cuenta',
          'Ajustes',
          'Compartir perfil',
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
      expect(rects[2].right, closeTo(390 - 16, 0.01));
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
        tester.getRect(find.byTooltip('Compartir perfil')).right,
        lessThanOrEqualTo(360),
      );
    });

    testWidgets('el grupo de botones no ocupa más ancho que el de antes', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 800), _header(taps: noop));

      final first = tester.getRect(find.byTooltip('Cambiar de cuenta'));
      final last = tester.getRect(find.byTooltip('Compartir perfil'));
      final width = last.right - first.left;
      // Antes eran 4 círculos de 36 con 10 de separación.
      const before = 4 * 36 + 3 * 10;
      expect(width, 3 * ProfileHeaderIconButton.touchTarget);
      expect(width, lessThan(before));
    });
  });

  group('ProfileScreen', () {
    test('la cabecera ya no tiene el botón del lápiz', () {
      final source = File(
        'lib/features/profile/presentation/screens/profile_screen.dart',
      ).readAsStringSync();

      expect(source.contains("label: 'Editar perfil'"), isFalse);
      expect(source.contains('Icons.edit_outlined'), isFalse);
      // Queda un solo botón que abre Ajustes.
      expect(RegExp("label: 'Ajustes'").allMatches(source).length, 1);
    });
  });
}
