import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_account_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_community_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_preferences_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_support_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_team_screen.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/theme/app_theme.dart';

Future<void> _pumpSettings(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: const SettingsScreen()),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

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

  group('Ajustes: el menú abre la vista de cada categoría', () {
    final categories = <String, Type>{
      'Cuenta': SettingsAccountScreen,
      'Preferencias': SettingsPreferencesScreen,
      'Comunidad': SettingsCommunityScreen,
      'Ayuda y soporte': SettingsSupportScreen,
    };

    categories.forEach((title, screenType) {
      testWidgets('"$title" abre su vista y permite volver', (tester) async {
        await _pumpSettings(tester);

        await tester.tap(find.widgetWithText(SettingsMenuButton, title));
        await _settle(tester);

        expect(find.byType(screenType), findsOneWidget);
        expect(find.byType(SettingsHeader), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Volver'));
        await _settle(tester);

        expect(find.byType(screenType), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });
    });

    testWidgets('los botones salen en orden, sin Equipo para un turista', (
      tester,
    ) async {
      await _pumpSettings(tester);
      const titles = ['Cuenta', 'Preferencias', 'Comunidad', 'Ayuda y soporte'];
      final ys = [
        for (final t in titles)
          tester.getTopLeft(find.widgetWithText(SettingsMenuButton, t)).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Equipo Níkara'), findsNothing);
      // "Sesión" va debajo de todos los botones del menú.
      expect(tester.getTopLeft(find.text('SESIÓN')).dy, greaterThan(ys.last));
    });

    testWidgets('el menú no repite las opciones de cada grupo', (tester) async {
      await _pumpSettings(tester);
      for (final option in [
        'Editar perfil',
        'Cambiar de cuenta',
        'Novedades de viaje',
        'Perfil público',
        'Registrar mi negocio',
      ]) {
        expect(find.text(option), findsNothing, reason: option);
      }
    });

    testWidgets(
      'Cuenta muestra sus filas y "Cambiar de cuenta" en otra tarjeta',
      (tester) async {
        await _pumpSettings(tester);
        await tester.tap(find.widgetWithText(SettingsMenuButton, 'Cuenta'));
        await _settle(tester);

        for (final row in [
          'Editar perfil',
          'Cambiar contraseña',
          'Correo electrónico',
          'Teléfono',
          'Cambiar de cuenta',
        ]) {
          expect(find.text(row), findsOneWidget, reason: row);
        }
        expect(find.byType(SettingsSection), findsNWidgets(2));
      },
    );

    testWidgets(
      'Preferencias muestra Notificaciones y Privacidad con sus interruptores',
      (tester) async {
        await _pumpSettings(tester);
        await tester.tap(
          find.widgetWithText(SettingsMenuButton, 'Preferencias'),
        );
        await _settle(tester);

        expect(find.text('NOTIFICACIONES'), findsOneWidget);
        expect(find.text('PRIVACIDAD'), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(5));
      },
    );

    testWidgets('Comunidad conserva las opciones de negocios y ECO', (
      tester,
    ) async {
      await _pumpSettings(tester);
      await tester.tap(find.widgetWithText(SettingsMenuButton, 'Comunidad'));
      await _settle(tester);

      for (final row in [
        'Registrar mi negocio',
        'Registrar actividad ECO',
        'Registrar / Gestionar Fundación',
      ]) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
    });

    testWidgets('"Equipo Níkara" no aparece para un turista', (tester) async {
      await _pumpSettings(tester);
      expect(find.text('Equipo Níkara'), findsNothing);
    });

    testWidgets('la vista de Equipo Níkara muestra el panel', (tester) async {
      final controller = SettingsController()..role = UserRole.admin;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsTeamScreen(controller: controller),
        ),
      );
      expect(find.text('Panel de administración'), findsOneWidget);
    });

    testWidgets('cerrar sesión y eliminar cuenta siguen en el menú', (
      tester,
    ) async {
      await _pumpSettings(tester);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Eliminar cuenta'), findsOneWidget);
    });

    testWidgets('los botones del menú miden al menos 48dp de alto', (
      tester,
    ) async {
      await _pumpSettings(tester);
      final buttons = find.byType(SettingsMenuButton);
      expect(buttons, findsWidgets);
      for (final element in buttons.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    });
  });

  group('Ajustes: el estado sobrevive a volver al menú', () {
    testWidgets('un interruptor conserva su valor al salir y reabrir', (
      tester,
    ) async {
      await _pumpSettings(tester);

      await tester.tap(find.widgetWithText(SettingsMenuButton, 'Preferencias'));
      await _settle(tester);
      // "Ofertas y promociones" arranca apagado.
      expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isFalse);
      await tester.tap(find.byType(Switch).at(2));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isTrue);

      await tester.tap(find.bySemanticsLabel('Volver'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(SettingsMenuButton, 'Preferencias'));
      await _settle(tester);

      expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isTrue);
    });
  });

  group('Ajustes: filas con valor a la derecha', () {
    testWidgets('el título queda en una línea y el correo se recorta', (
      tester,
    ) async {
      final controller = SettingsController()
        ..email =
            'una.direccion.de.correo.larguisima.para.forzar.el.recorte@'
            'dominio-extremadamente-largo-de-prueba.example.com'
        ..phone = '+505 8888 8888';
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsAccountScreen(controller: controller),
        ),
      );

      final title = tester.renderObject<RenderParagraph>(
        find.text('Correo electrónico'),
      );
      final line = title.preferredLineHeight;
      expect(title.size.height, closeTo(line, 1), reason: 'una sola línea');

      final value = tester.widget<Text>(find.text(controller.email));
      expect(value.maxLines, 1);
      expect(value.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });
}
