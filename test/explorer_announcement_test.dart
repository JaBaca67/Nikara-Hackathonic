import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nikara_app/features/profile/presentation/screens/explorer_plans_screen.dart';
import 'package:nikara_app/features/profile/presentation/widgets/explorer_announcement_banner.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget bannerApp({required bool active, bool reducedMotion = true}) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExplorerAnnouncementBanner(isActive: active),
          ),
        ),
      );

  testWidgets(
    'el reflejo se pausa al salir, en segundo plano y al reducir movimiento',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(bannerApp(active: true, reducedMotion: false));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.tap(find.text('Unirme'));
      await tester.pumpAndSettle();
      expect(find.byType(ExplorerPlansScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Níkara Explorador'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(bannerApp(active: false, reducedMotion: false));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(bannerApp(active: true, reducedMotion: false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(bannerApp(active: true));
      await tester.pumpAndSettle();
      expect(find.text('Níkara Explorador'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.byTooltip('Cerrar anuncio'));
      await tester.pumpAndSettle();
      expect(find.text('Níkara Explorador'), findsNothing);
    },
  );

  testWidgets('cuenta entradas al perfil, sin contar reconstrucciones', (
    tester,
  ) async {
    await tester.pumpWidget(bannerApp(active: false));
    expect(find.text('Níkara Explorador'), findsNothing);

    for (var visit = 1; visit <= 7; visit++) {
      await tester.pumpWidget(bannerApp(active: true));
      expect(
        find.text('Níkara Explorador'),
        visit == 1 || visit == 4 || visit == 7 ? findsOneWidget : findsNothing,
        reason: 'Visita $visit',
      );
      await tester.pumpWidget(bannerApp(active: true));
      expect(
        find.text('Níkara Explorador'),
        visit == 1 || visit == 4 || visit == 7 ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(bannerApp(active: false));
    }
  });

  testWidgets('cerrar no navega y el anuncio vuelve en la cuarta visita', (
    tester,
  ) async {
    await tester.pumpWidget(bannerApp(active: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar anuncio'));
    await tester.pump();
    expect(find.text('Níkara Explorador'), findsNothing);
    expect(find.byType(ExplorerPlansScreen), findsNothing);

    await tester.pumpWidget(bannerApp(active: true));
    expect(find.text('Níkara Explorador'), findsNothing);
    for (var visit = 2; visit <= 4; visit++) {
      await tester.pumpWidget(bannerApp(active: false));
      await tester.pumpWidget(bannerApp(active: true));
    }
    expect(find.text('Níkara Explorador'), findsOneWidget);
  });

  testWidgets('el anuncio abre la comparación y permite regresar al perfil', (
    tester,
  ) async {
    await tester.pumpWidget(bannerApp(active: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(find.byType(ExplorerPlansScreen), findsOneWidget);
    expect(find.text('Versión gratuita'), findsOneWidget);
    expect(find.text('EXPLORADOR'), findsOneWidget);
    expect(
      find.text('Gratis para explorar. Más poder con Explorador.'),
      findsOneWidget,
    );
    expect(find.text(r'US$2.50'), findsOneWidget);
    expect(find.text(r'o C$93 / mes'), findsOneWidget);
    expect(find.text('Acceso completo a la IA de Níkara'), findsOneWidget);
    expect(
      find.textContaining('más tokens y menos restricciones'),
      findsOneWidget,
    );
    expect(
      find.text('Sistema de rutas: hasta 6 rutas guardadas'),
      findsOneWidget,
    );
    await tester.tap(find.text('Conocer Explorador'));
    await tester.pumpAndSettle();
    final carousel = find.byKey(const ValueKey('explorer-benefits-carousel'));
    await tester.ensureVisible(carousel);
    await tester.pumpAndSettle();
    final initialHeight = tester.getSize(carousel).height;
    expect(find.text('1 de 6 beneficios'), findsOneWidget);
    expect(
      find.text('Acceso completo a la IA de Níkara').hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
          )
          .onPressed,
      isNull,
    );
    await tester.drag(
      carousel,
      Offset(-tester.getSize(carousel).width * 0.8, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 de 6 beneficios'), findsOneWidget);
    expect(find.text('Mapas sin conexión').hitTestable(), findsOneWidget);
    expect(
      find.text('Acceso completo a la IA de Níkara').hitTestable(),
      findsNothing,
    );
    expect(
      find.text('Descarga de mapas y navegación sin conexión'),
      findsOneWidget,
    );

    for (final (page, title) in const [
      (3, 'Rutas guardadas ilimitadas'),
      (4, 'Un perfil a tu estilo'),
      (5, 'Insignia de explorador'),
      (6, 'Atención prioritaria'),
    ]) {
      await tester.ensureVisible(find.byTooltip('Siguiente beneficio'));
      await tester.tap(find.byTooltip('Siguiente beneficio'));
      await tester.pumpAndSettle();
      expect(find.text('$page de 6 beneficios'), findsOneWidget);
      expect(find.text(title).hitTestable(), findsOneWidget);
      expect(tester.getSize(carousel).height, initialHeight);
    }
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Beneficio anterior'));
    await tester.pumpAndSettle();
    expect(find.text('5 de 6 beneficios'), findsOneWidget);
    expect(find.text('Insignia de explorador').hitTestable(), findsOneWidget);

    await tester.ensureVisible(find.text('Quiero ser Explorador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiero ser Explorador'));
    await tester.pumpAndSettle();
    expect(find.text('Tu próxima aventura está cerca'), findsOneWidget);
    expect(find.textContaining('cuando esté disponible.'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Níkara Explorador'), findsOneWidget);
  });

  testWidgets('con movimiento reducido el anuncio queda visible de inmediato', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: ExplorerAnnouncementBanner()),
      ),
    );
    expect(find.text('Unirme').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(find.byType(ExplorerPlansScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (1000.0, 1.0)]) {
    testWidgets('comparación legible a $width dp y escala $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget app(Widget home) => MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: home,
      );
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: SingleChildScrollView(child: ExplorerAnnouncementBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Unirme'));
      await tester.pumpAndSettle();
      expect(find.text('Unirme').hitTestable(), findsOneWidget);
      await tester.pumpWidget(app(const ExplorerPlansScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Siguiente beneficio'));
      await tester.pumpAndSettle();
      for (var page = 2; page <= 6; page++) {
        await tester.tap(find.byTooltip('Siguiente beneficio'));
        await tester.pumpAndSettle();
        expect(find.text('$page de 6 beneficios'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final notice = find.textContaining(
        'Estamos preparando Níkara Explorador.',
      );
      await tester.ensureVisible(notice);
      await tester.pumpAndSettle();
      expect(notice.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
