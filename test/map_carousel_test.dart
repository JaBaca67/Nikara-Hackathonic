import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_fab.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_bottom_dock.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_carousel.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _navigationKey = ValueKey('navigation');
const _locationKey = ValueKey('location');
const _firstKey = ValueKey('first');
const _secondKey = ValueKey('second');
const _thirdKey = ValueKey('third');

Widget _host(
  PageController controller,
  List<Widget> cards, {
  double scale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      extendBody: true,
      bottomNavigationBar: const SizedBox(key: _navigationKey, height: 112),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MapBottomDock(
              recommendationLabel: const Text('Recomendaciones destacadas'),
              locationControl: const SizedBox(
                key: _locationKey,
                width: 48,
                height: 48,
              ),
              assistantControl: const AssistantFab(),
              panel: MapCarousel(controller: controller, children: cards),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _card(Key key, double height) => SizedBox(
  key: key,
  child: AnimatedSize(
    duration: const Duration(milliseconds: 200),
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      height: height,
      child: const ColoredBox(color: Colors.white),
    ),
  ),
);

void _expectAttached(WidgetTester tester, Key activeCard) {
  final card = tester.getRect(find.byKey(activeCard).last);
  final carousel = tester.getRect(find.byType(MapCarousel));
  final assistant = tester.getRect(find.byType(AssistantFab));
  final location = tester.getRect(find.byKey(_locationKey));
  final navigation = tester.getRect(find.byKey(_navigationKey));
  expect(carousel.top, closeTo(card.top, 0.1));
  expect(card.top - assistant.bottom, closeTo(AppSpacing.md, 0.1));
  expect(carousel.bottom, closeTo(navigation.top - AppSpacing.sm, 0.1));
  expect(location.bottom, lessThan(assistant.top));
  expect(assistant.right, closeTo(location.right, 0.1));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('los controles siguen la altura real al expandir y contraer', (
    tester,
  ) async {
    final controller = PageController(viewportFraction: 0.88);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, [_card(_firstKey, 88)]));
    await tester.pumpAndSettle();
    _expectAttached(tester, _firstKey);

    for (final height in [238.0, 88.0]) {
      await tester.pumpWidget(_host(controller, [_card(_firstKey, height)]));
      await tester.pump();
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        // La medida del frame se aplica al dock en el siguiente layout.
        await tester.pump();
        _expectAttached(tester, _firstKey);
      }
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(MapCarousel)).height, height);
    }
  });

  testWidgets('una selección fuera de pantalla no deja espacio vacío', (
    tester,
  ) async {
    final controller = PageController(viewportFraction: 0.88);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller, [
        _card(_firstKey, 238),
        _card(_secondKey, 88),
        _card(_thirdKey, 88),
      ]),
    );
    await tester.pumpAndSettle();
    _expectAttached(tester, _firstKey);

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(MapCarousel)).height, 88);
    _expectAttached(tester, _thirdKey);

    controller.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(MapCarousel)).height, 238);
    _expectAttached(tester, _firstKey);
  });

  testWidgets(
    'las tarjetas que asoman no reservan altura y filtrar vuelve a medir',
    (tester) async {
      final controller = PageController(viewportFraction: 0.88);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(controller, [_card(_firstKey, 88), _card(_secondKey, 130)]),
      );
      await tester.pumpAndSettle();
      _expectAttached(tester, _firstKey);
      await tester.pumpWidget(_host(controller, [_card(_thirdKey, 96)]));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(MapCarousel)).height, 96);
      _expectAttached(tester, _thirdKey);
    },
  );

  testWidgets(
    'la última tarjeta compacta libera la altura del borde expandido',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      addTearDown(tester.view.reset);
      final controller = PageController(viewportFraction: 0.88);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(controller, [_card(_firstKey, 238), _card(_secondKey, 88)]),
      );
      await tester.pumpAndSettle();
      _expectAttached(tester, _firstKey);
      await tester.drag(find.byType(PageView), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_firstKey).last).right, greaterThan(0));
      expect(tester.getSize(find.byType(MapCarousel)).height, 88);
      _expectAttached(tester, _secondKey);
      controller.jumpToPage(0);
      await tester.pumpAndSettle();
      _expectAttached(tester, _firstKey);
    },
  );

  testWidgets('texto grande y asistente expandido conservan el anclaje', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    final controller = PageController(viewportFraction: 0.88);
    addTearDown(controller.dispose);
    final card = Padding(
      key: _firstKey,
      padding: const EdgeInsets.all(12),
      child: Text(
        'Casa Réplica · Museo Rubén Darío\nManagua\nSin reseñas\nCómo llegar · Ver perfil',
        style: const TextStyle(fontSize: 18, height: 1.2),
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
    await tester.pumpWidget(_host(controller, [card]));
    await tester.pumpAndSettle();
    final compactHeight = tester.getSize(find.byType(MapCarousel)).height;
    await tester.pumpWidget(_host(controller, [card], scale: 1.6));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(MapCarousel)).height,
      greaterThan(compactHeight),
    );
    expect(find.byType(AssistantFab).hitTestable(), findsOneWidget);
    await tester.longPress(find.byType(AssistantFab));
    await tester.pump();
    expect(find.text('Abre Níkara IA'), findsOneWidget);
    _expectAttached(tester, _firstKey);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    _expectAttached(tester, _firstKey);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
