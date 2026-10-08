import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

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

  group('Ajustes: confirmaciones con AppConfirmDialog', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const SettingsScreen()),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(label),
    );

    testWidgets('cerrar sesión pregunta y "Cancelar" no hace nada', (
      tester,
    ) async {
      await openSettings(tester);
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('¿Seguro que quieres cerrar tu sesión de Níkara?'),
        findsOneWidget,
      );

      await tester.tap(dialogButton('Cancelar'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Cerrando sesión…'), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('eliminar cuenta pregunta y "Cancelar" no hace nada', (
      tester,
    ) async {
      await openSettings(tester);
      await tester.ensureVisible(find.text('Eliminar cuenta'));
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Esta acción es permanente'), findsOneWidget);

      await tester.tap(dialogButton('Cancelar'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Eliminando tu cuenta…'), findsNothing);
    });

    testWidgets('si eliminar la cuenta falla, avisa y libera la pantalla', (
      tester,
    ) async {
      await openSettings(tester);
      await tester.ensureVisible(find.text('Eliminar cuenta'));
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pump(const Duration(milliseconds: 400));
      // El título del diálogo se llama igual que el botón: se apunta al botón.
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar cuenta'));

      // El backend de prueba no responde: la acción falla y debe terminar
      // con un aviso en español y sin la pantalla bloqueada.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(SnackBar).evaluate().isNotEmpty) break;
      }

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Eliminando tu cuenta…'), findsNothing);
      final button = find.text('Eliminar cuenta');
      expect(button, findsWidgets);
    });
  });

  group('Migración a AppConfirmDialog', () {
    // Los sitios migrados del Lote A: ninguno debe volver a armar su propio
    // diálogo de confirmación. Valor = (usos de AppConfirmDialog.show esperados,
    // `showDialog<bool>` que se quedan a propósito). Ajustes conserva uno: el
    // formulario de cambiar contraseña, que no es una confirmación.
    const migrated = <String, (int, int)>{
      'lib/features/business/presentation/screens/manage_business_posts_screen.dart':
          (1, 0),
      'lib/features/settings/presentation/screens/settings_screen.dart': (2, 1),
      'lib/features/profile/presentation/screens/face_profile_screen.dart': (
        1,
        0,
      ),
      'lib/features/routes/presentation/screens/route_detail_screen.dart': (
        1,
        0,
      ),
      'lib/features/eco/presentation/screens/edit_organization_screen.dart': (
        1,
        0,
      ),
      'lib/shared/widgets/account_switcher_sheet.dart': (1, 0),
    };

    migrated.forEach((path, expected) {
      test(path.split('/').last, () {
        final source = File(path).readAsStringSync();
        expect(
          'AppConfirmDialog.show('.allMatches(source).length,
          expected.$1,
          reason: '$path: usos de AppConfirmDialog.show',
        );
        expect(
          'showDialog<bool>('.allMatches(source).length,
          expected.$2,
          reason: '$path volvió a armar su propio diálogo de confirmación',
        );
      });
    });
  });
}
