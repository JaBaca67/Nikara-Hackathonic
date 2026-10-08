import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_fab.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/nikara_butterfly.dart';

Widget _host({
  bool reduced = false,
  bool animated = true,
  ButterflyMood mood = ButterflyMood.idle,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: NikaraButterfly(size: 140, mood: mood, animated: animated),
      ),
    ),
  );
}

List<double> _wingScales(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .where(
      (transform) =>
          transform.key is ValueKey<String> &&
          (transform.key as ValueKey<String>).value.startsWith(
            'butterfly-wing-',
          ),
    )
    .map((transform) => transform.transform.entry(0, 0))
    .toList();

void main() {
  testWidgets('el icono flotante mantiene la mariposa estática', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AssistantFab())),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.widget<NikaraButterfly>(find.byType(NikaraButterfly)).animated,
      isFalse,
    );
    expect(_wingScales(tester), everyElement(1.0));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('puede detener y reanudar el aleteo sin movimiento reducido', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_host(animated: false));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(_wingScales(tester), everyElement(1.0));
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    expect(_wingScales(tester), everyElement(lessThan(1.0)));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('las alas pliegan con profundidad y desfase', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 550));
    final lower = tester.widget<Transform>(
      find.byKey(const ValueKey('butterfly-wing-0')),
    );
    final upper = tester.widget<Transform>(
      find.byKey(const ValueKey('butterfly-wing-2')),
    );
    expect(upper.transform.entry(2, 0).abs(), greaterThan(0.1));
    expect(upper.transform.entry(3, 0).abs(), greaterThan(0));
    expect(
      lower.transform.entry(0, 0),
      isNot(closeTo(upper.transform.entry(0, 0), 0.01)),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'carga los SVG y detiene y reanuda el movimiento con accesibilidad',
    (tester) async {
      await tester.pumpWidget(_host(reduced: true));
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNWidgets(12));
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(_wingScales(tester), everyElement(1.0));

      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      expect(_wingScales(tester), everyElement(lessThan(1.0)));

      await tester.pumpWidget(_host(reduced: true));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_wingScales(tester), everyElement(1.0));
    },
  );

  testWidgets('pensar cambia el período mientras el aleteo está activo', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_host(mood: ButterflyMood.thinking));
    final before = _wingScales(tester);

    await tester.pump(const Duration(milliseconds: 425));
    expect(_wingScales(tester).first, isNot(closeTo(before.first, 0.01)));
    await tester.pump(const Duration(milliseconds: 425));
    final after = _wingScales(tester);
    for (var i = 0; i < before.length; i++) {
      expect(after[i], closeTo(before[i], 0.001));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
