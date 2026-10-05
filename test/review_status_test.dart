import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/my_business/presentation/widgets/my_business_widgets.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// `ReviewStatusPill` existía desde antes, pero en el panel de una fundación
/// solo se llegaba a ver en `aprobado`: el listado pedía las jornadas con el
/// filtro `status = 'aprobado'` fijo, así que las otras dos ramas del `switch`
/// nunca se dibujaban. Al levantar ese filtro para el dueño, estas dos
/// etiquetas pasan a ser lo único que le dice qué pasó con su solicitud.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: Center(child: child)),
  );

  group('ReviewStatus', () {
    test('las etiquetas están en español y en términos del dueño', () {
      expect(ReviewStatus.pendiente.label, 'En revisión');
      expect(ReviewStatus.aprobado.label, 'Publicado');
      expect(ReviewStatus.rechazado.label, 'Necesita ajustes');
    });

    test('fromWire lee los valores que viajan a Postgres', () {
      expect(ReviewStatus.fromWire('pendiente'), ReviewStatus.pendiente);
      expect(ReviewStatus.fromWire('aprobado'), ReviewStatus.aprobado);
      expect(ReviewStatus.fromWire('rechazado'), ReviewStatus.rechazado);
    });

    test(
      'un valor ausente o desconocido degrada a aprobado, no a pendiente',
      () {
        // Va en la dirección segura: tratar una fila vieja como pendiente
        // esconderría contenido ya publicado y dejaría la app vacía.
        expect(ReviewStatus.fromWire(null), ReviewStatus.aprobado);
        expect(ReviewStatus.fromWire(''), ReviewStatus.aprobado);
        expect(ReviewStatus.fromWire('vigente'), ReviewStatus.aprobado);
      },
    );
  });

  group('ReviewStatusPill', () {
    for (final status in ReviewStatus.values) {
      testWidgets('dibuja la etiqueta de ${status.wireValue}', (tester) async {
        await tester.pumpWidget(wrap(ReviewStatusPill(status: status)));

        expect(find.text(status.label), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      });
    }

    testWidgets('cada estado usa un ícono distinto de los otros dos', (
      tester,
    ) async {
      final icons = <IconData>[];
      for (final status in ReviewStatus.values) {
        await tester.pumpWidget(wrap(ReviewStatusPill(status: status)));
        icons.add(tester.widget<Icon>(find.byType(Icon)).icon!);
      }

      expect(
        icons.toSet().length,
        ReviewStatus.values.length,
        reason: 'el ícono tiene que distinguir el estado por sí solo, sin leer',
      );
    });

    testWidgets('no desborda en el ancho angosto de la tarjeta del panel', (
      tester,
    ) async {
      // La etiqueta más larga ("Necesita ajustes") convive con el título de la
      // jornada y el botón de editar en la misma fila.
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 120,
            child: ReviewStatusPill(status: ReviewStatus.rechazado),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
