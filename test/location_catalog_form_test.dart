import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/core/models/geographic_destination.dart';
import 'package:nikara_app/shared/widgets/origin_autocomplete_field.dart';
import 'package:nikara_app/shared/widgets/nicaragua_location_form_fields.dart';
import 'package:nikara_app/theme/app_theme.dart';

void main() {
  testWidgets(
    'formulario compartido guarda cabecera y municipio; escritura con sugerencias exige seleccionar un resultado',
    (tester) async {
      final form = GlobalKey<FormState>();
      NicaraguaOriginPlace? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: form,
              child: NicaraguaLocationFormFields(
                onChanged: (p) => selected = p,
              ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      expect(find.text('Nicaragua'), findsOneWidget);
      await tester.tap(
        find.byType(OriginAutocompleteField<NicaraguaOriginPlace>),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad / municipio *'),
        'manguas',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(selected, isNull);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad / municipio *'),
        'malpaisillo',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Malpaisillo'));
      await tester.pumpAndSettle();
      expect(selected?.municipality, 'Larreynaga');
      expect(selected?.city, 'Malpaisillo');
      expect(form.currentState!.validate(), isTrue);
      await tester.tap(find.byType(OriginAutocompleteField<String>));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Departamento'),
        'esteli',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Estelí'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(form.currentState!.validate(), isFalse);
      await tester.tap(
        find.byType(OriginAutocompleteField<NicaraguaOriginPlace>),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad / municipio *'),
        'Managua',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad / municipio *'),
        'trinidad',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'La Trinidad'));
      await tester.pumpAndSettle();
      expect(selected?.department, 'Estelí');
      expect(selected?.municipalityCode, '2525');
    },
  );
  testWidgets('editar precarga el municipio y el país del catálogo', (
    tester,
  ) async {
    final place = resolveMunicipality('bilwi');
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Form(
            key: form,
            child: NicaraguaLocationFormFields(
              initialValue: place,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Nicaragua'), findsOneWidget);
    expect(find.text('Bilwi'), findsOneWidget);
    expect(find.text('Municipio: Puerto Cabezas'), findsOneWidget);
    expect(form.currentState!.validate(), isTrue);
  });
}
