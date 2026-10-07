import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';
import 'package:nikara_app/features/ai_assistant/presentation/screens/assistant_screen.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_chat_widgets.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/nikara_butterfly.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'el encabezado blanco cubre también el área de la barra de estado',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.only(top: 36),
              disableAnimations: true,
            ),
            child: AssistantScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find
          .ancestor(
            of: find.text('Níkara IA'),
            matching: find.byType(Container),
          )
          .first;
      final decoration =
          tester.widget<Container>(header).decoration as BoxDecoration;
      expect(decoration.color, AppColors.surface);
      expect(tester.getTopLeft(header).dy, 0);
      expect(
        tester.getTopLeft(find.text('Níkara IA')).dy,
        greaterThanOrEqualTo(36),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el hilo y el estado de espera admiten texto ampliado', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AssistantMessageBubble(
                  message: AssistantMessage.fromReply(
                    const AssistantReply(
                      text:
                          'Podemos armar una ruta por Granada, visitar la laguna '
                          'de Apoyo y conocer emprendimientos locales. Contame '
                          'cuántos días tenés y qué experiencias te gustan.',
                    ),
                  ),
                  places: const {},
                  onOpenProfile: (_) {},
                  onShowOnMap: (_) {},
                  onSaveItinerary: (_) {},
                  savingItinerary: null,
                  savedItineraries: const {},
                ),
                const AssistantTypingBubble(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('la bienvenida se adapta a teléfonos pequeños y texto grande', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 384.0]) {
      for (final scale in [1.0, 1.6]) {
        tester.view.physicalSize = Size(width, 740);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 740),
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: const AssistantScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width / $scale');
        expect(find.byType(NikaraButterfly), findsOneWidget);
        expect(find.text('Tu guía de viaje'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Una escapada'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Una escapada').hitTestable(), findsOneWidget);
      }
    }
  });

  testWidgets('el campo queda visible con teclado y solo envía texto', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(384, 740);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              AssistantComposer(
                controller: controller,
                enabled: true,
                onSubmit: (text) => submitted = text,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(find.byType(TextField)).dy,
      lessThanOrEqualTo(440),
    );
    final sendButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Enviar mensaje',
    );
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Una ruta por Granada');
    await tester.pump();
    await tester.tap(sendButton);
    expect(submitted, 'Una ruta por Granada');
  });
}
