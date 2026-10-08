import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_moment_state.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_moment_policy_sheet.dart';
import 'package:nikara_app/features/eco/utils/eco_icons.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  const state = EcoMomentState(enabled: true, canManage: true, canPost: true);

  test('las categorías cubren conservación, formación y manejo ambiental', () {
    expect(kEcoCategories.toSet().length, 10);
    expect(
      kEcoCategories,
      containsAll([
        'Reforestación',
        'Fauna',
        'Limpieza',
        'Agua y cuencas',
        'Suelos y agroecología',
        'Saneamiento ambiental',
      ]),
    );
    expect(kEcoCategories.map(ecoCategoryIcon).toSet().length, 10);
  });

  test(
    'los permisos y límites se interpretan desde la respuesta del servidor',
    () {
      final policy = EcoMomentState.fromJson({
        'enabled': false,
        'can_manage': false,
        'can_post': false,
        'max_accounts': 2,
        'account_count': 2,
        'blocked_reason': 'Foro cerrado',
      });
      expect(policy.canPost, isFalse);
      expect(policy.canManage, isFalse);
      expect(policy.maxAccounts, 2);
      expect(policy.maxMessages, isNull);
      expect(policy.blockedReason, 'Foro cerrado');
    },
  );

  testWidgets('valida cero y guarda cierre con límites independientes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: EcoMomentPolicySheet(
            state: state,
            onSave:
                ({
                  required enabled,
                  maxMessages,
                  maxAccounts,
                  maxPerAccount,
                }) async {
                  saved = {
                    'enabled': enabled,
                    'messages': maxMessages,
                    'accounts': maxAccounts,
                    'perAccount': maxPerAccount,
                  };
                  return state;
                },
          ),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '0');
    await tester.ensureVisible(find.text('Guardar configuración'));
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Ingresa un número entre 1 y 2147483647'), findsOneWidget);
    await tester.enterText(fields.at(0), '30');
    await tester.enterText(fields.at(1), '10');
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar configuración'));
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    expect(saved, {
      'enabled': false,
      'messages': 30,
      'accounts': 10,
      'perAccount': null,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('mantiene la configuración abierta si falla el servidor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: EcoMomentPolicySheet(
            state: state,
            onSave:
                ({
                  required enabled,
                  maxMessages,
                  maxAccounts,
                  maxPerAccount,
                }) async => throw Exception('Conexión fallida'),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Guardar configuración'));
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se guardaron los cambios. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
