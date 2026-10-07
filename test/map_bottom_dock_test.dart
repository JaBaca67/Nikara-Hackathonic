import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_fab.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_bottom_dock.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _panelKey = ValueKey('panel');
const _navigationKey = ValueKey('navigation');
const _locationKey = ValueKey('location');
const _labelKey = ValueKey('recommendation-label');

Widget _host({
  double? panelHeight,
  bool navigating = false,
  double scale = 1,
  bool reduced = true,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduced,
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: Scaffold(
      extendBody: true,
      bottomNavigationBar: navigating
          ? null
          : const SizedBox(key: _navigationKey, height: 112),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MapBottomDock(
              recommendationLabel: !navigating && panelHeight != null
                  ? const SizedBox(key: _labelKey, height: 28)
                  : null,
              leading: navigating
                  ? const SizedBox(width: 76, height: 64)
                  : null,
              locationControl: SizedBox(
                key: _locationKey,
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.my_location),
                ),
              ),
              assistantControl: navigating ? null : const AssistantFab(),
              panel: panelHeight == null
                  ? null
                  : SizedBox(key: _panelKey, height: panelHeight),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'el asistente puede expandirse con el aleteo activo sin cubrir la tarjeta',
    (tester) async {
      await tester.pumpWidget(_host(panelHeight: 168, reduced: false));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.longPress(find.byType(AssistantFab));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Abre Níkara IA'), findsOneWidget);
      expect(
        tester.getRect(find.byType(AssistantFab)).bottom,
        lessThan(tester.getRect(find.byKey(_panelKey)).top),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'controles y panel respetan la barra inferior y el asistente expandido',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      for (final height in [108.0, 168.0, 260.0]) {
        await tester.pumpWidget(_host(panelHeight: height, scale: 1.6));
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(AssistantFab));
        await tester.pump();
        expect(find.text('Abre Níkara IA'), findsOneWidget);
        final panel = tester.getRect(find.byKey(_panelKey));
        final location = tester.getRect(find.byKey(_locationKey));
        final assistant = tester.getRect(find.byType(AssistantFab));
        final navigation = tester.getRect(find.byKey(_navigationKey));
        expect(panel.bottom, lessThanOrEqualTo(navigation.top));
        expect(location.bottom, lessThan(panel.top));
        expect(assistant.bottom, lessThan(panel.top));
        expect(location.bottom, lessThan(assistant.top));
        expect(location.right, closeTo(assistant.right, 0.1));
        expect(assistant.right, closeTo(304, 0.1));
        expect(
          tester.getRect(find.byKey(_labelKey)).bottom,
          closeTo(assistant.bottom, 0.1),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'sin tarjetas y durante navegación mantiene controles accesibles',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.byType(AssistantFab).hitTestable(), findsOneWidget);
      expect(find.byKey(_locationKey).hitTestable(), findsOneWidget);
      await tester.pumpWidget(_host(panelHeight: 230, navigating: true));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantFab), findsNothing);
      expect(find.byKey(_navigationKey), findsNothing);
      expect(
        tester.getRect(find.byKey(_locationKey)).bottom,
        lessThan(tester.getRect(find.byKey(_panelKey)).top),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
