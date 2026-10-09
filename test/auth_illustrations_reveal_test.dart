import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/shared/widgets/auth/auth_bottom_sheet_layout.dart';
import 'package:nikara_app/shared/widgets/auth/auth_scene_backdrop.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _topAsset = 'assets/images/parte_arriba_nikara.png';
const _bottomAsset = 'assets/images/parte_abajo_login.png';

Finder _imageOf(String asset) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == asset,
);

/// Opacidad y desplazamiento vertical efectivos de la ilustración [asset].
({double opacity, double dy}) _stateOf(WidgetTester tester, String asset) {
  final fade = tester.widget<FadeTransition>(
    find
        .ancestor(of: _imageOf(asset), matching: find.byType(FadeTransition))
        .first,
  );
  final translate = tester.widget<Transform>(
    find.ancestor(of: _imageOf(asset), matching: find.byType(Transform)).first,
  );
  return (
    opacity: fade.opacity.value,
    dy: translate.transform.getTranslation().y,
  );
}

Widget _app(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: MaterialApp(theme: AppTheme.lightTheme, home: child),
);

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

  group('AuthSceneBackdrop: entrada de las ilustraciones', () {
    testWidgets('arrancan ocultas y desplazadas hacia su borde', (
      tester,
    ) async {
      final reveal = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 650),
      );
      addTearDown(reveal.dispose);

      await tester.pumpWidget(
        _app(Scaffold(body: AuthSceneBackdrop(illustrationsReveal: reveal))),
      );

      final top = _stateOf(tester, _topAsset);
      final bottom = _stateOf(tester, _bottomAsset);
      expect(top.opacity, 0);
      expect(
        top.dy,
        lessThan(0),
        reason: 'la de arriba empieza sobre su borde',
      );
      expect(bottom.opacity, 0);
      expect(
        bottom.dy,
        greaterThan(0),
        reason: 'la de abajo empieza bajo su borde',
      );
    });

    testWidgets('terminan opacas, en su sitio y la de abajo llega después', (
      tester,
    ) async {
      final reveal = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 650),
      );
      addTearDown(reveal.dispose);

      await tester.pumpWidget(
        _app(Scaffold(body: AuthSceneBackdrop(illustrationsReveal: reveal))),
      );

      reveal.value = 0.3;
      await tester.pump();
      expect(
        _stateOf(tester, _topAsset).opacity,
        greaterThan(_stateOf(tester, _bottomAsset).opacity),
        reason: 'desfase: la de arriba va por delante',
      );

      reveal.value = 1;
      await tester.pump();
      for (final asset in [_topAsset, _bottomAsset]) {
        final state = _stateOf(tester, asset);
        expect(state.opacity, 1);
        expect(state.dy, 0);
      }
    });

    testWidgets('sin animación externa quedan visibles y fijas', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const Scaffold(body: AuthSceneBackdrop())));

      expect(_imageOf(_topAsset), findsOneWidget);
      expect(_imageOf(_bottomAsset), findsOneWidget);
      expect(_stateOf(tester, _topAsset).opacity, 1);
      expect(_stateOf(tester, _bottomAsset).dy, 0);
    });
  });

  group('AuthBottomSheetLayout: entrada de las ilustraciones', () {
    testWidgets('animan: al montar aún no son visibles y luego aparecen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const AuthBottomSheetLayout(child: SizedBox(height: 40))),
      );

      expect(_stateOf(tester, _topAsset).opacity, 0);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_stateOf(tester, _topAsset).opacity, 1);
      expect(_stateOf(tester, _bottomAsset).opacity, 1);
      expect(_stateOf(tester, _bottomAsset).dy, 0);
    });

    testWidgets('con movimiento reducido aparecen de golpe, sin animar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const AuthBottomSheetLayout(child: SizedBox(height: 40)),
          disableAnimations: true,
        ),
      );

      for (final asset in [_topAsset, _bottomAsset]) {
        final state = _stateOf(tester, asset);
        expect(state.opacity, 1, reason: '$asset visible en el primer frame');
        expect(state.dy, 0);
      }
    });
  });
}
