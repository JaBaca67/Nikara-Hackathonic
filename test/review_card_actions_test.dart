import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/business/data/review_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _me = 'user-me';
const _menuTooltip = 'Opciones de tu reseña';

ReviewModel _review(String id, String author, double rating, String comment) =>
    ReviewModel(
      id: id,
      authorId: author,
      authorName: author == _me ? 'Yo' : 'Otra persona',
      rating: rating,
      comment: comment,
      date: DateTime(2026, 10, 1),
    );

BusinessModel _business(List<ReviewModel> reviews) => BusinessModel(
  id: 'review-card-test',
  name: 'Café del Lago',
  category: 'Gastronomía',
  subcategory: 'Cafetería',
  description: 'Café de altura frente al lago.',
  city: 'Granada',
  locationText: 'Frente al parque central',
  latitude: 11.93,
  longitude: -85.95,
  contactPhone: '+505 8888 8888',
  hostName: 'Ana',
  ownerId: 'owner-id',
  reviews: reviews,
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

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  Future<void> open(
    WidgetTester tester, {
    required List<ReviewModel> reviews,
    String? userId = _me,
    Future<ReviewWriteOutcome> Function(BusinessModel, ReviewModel)? save,
    Future<void> Function(BusinessModel)? delete,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BusinessDetailScreen(
          business: _business(reviews),
          userIdOverride: userId,
          saveReviewOverride: save,
          deleteReviewOverride: delete,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Reseñas & Fotos'));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    // Las pantallas con Realtime agendan un timer de desconexión al cerrar.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  }

  Future<void> openMenuAndPick(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip(_menuTooltip));
    await settle(tester);
    await settle(tester);
    await tester.tap(find.text(item));
    await settle(tester);
    await settle(tester);
  }

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  final both = [
    _review('1', _me, 5, 'Mi opinión original'),
    _review('2', 'otra', 3, 'Opinión ajena'),
  ];

  group('Menú de la tarjeta', () {
    testWidgets('la reseña propia lo muestra y la ajena no', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, reviews: both);

      expect(find.byTooltip(_menuTooltip), findsOneWidget);
      expect(find.bySemanticsLabel(_menuTooltip), findsOneWidget);
      expect(find.text('Mi opinión original'), findsOneWidget);
      expect(find.text('Opinión ajena'), findsOneWidget);

      // Zona táctil de al menos 48dp.
      final size = tester.getSize(find.byTooltip(_menuTooltip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('sin sesión (invitado) no aparece en ninguna tarjeta', (
      tester,
    ) async {
      await open(tester, reviews: both, userId: null);
      expect(find.byTooltip(_menuTooltip), findsNothing);
      await unmount(tester);
    });

    testWidgets('si solo hay reseñas ajenas no aparece', (tester) async {
      await open(tester, reviews: [both[1]]);
      expect(find.byTooltip(_menuTooltip), findsNothing);
      await unmount(tester);
    });

    testWidgets('ofrece "Editar" y "Eliminar"', (tester) async {
      await open(tester, reviews: both);
      await tester.tap(find.byTooltip(_menuTooltip));
      await settle(tester);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Editar desde la tarjeta', () {
    testWidgets('abre la hoja con lo actual y guardar actualiza', (
      tester,
    ) async {
      ReviewModel? saved;
      await open(
        tester,
        reviews: both,
        save: (business, review) async {
          saved = review;
          return ReviewWriteOutcome.updated;
        },
      );

      await openMenuAndPick(tester, 'Editar');

      expect(find.byType(WriteReviewSheet), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Mi opinión original');

      await tester.enterText(find.byType(TextField), 'Mi opinión nueva');
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(saved?.comment, 'Mi opinión nueva');
      expect(find.byType(WriteReviewSheet), findsNothing);
      expect(find.text('Actualizaste tu reseña'), findsOneWidget);
      // Sigue habiendo una sola reseña mía: se reemplazó, no se duplicó.
      expect(find.text('Mi opinión nueva'), findsOneWidget);
      expect(find.text('Mi opinión original'), findsNothing);
      expect(find.byTooltip(_menuTooltip), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('si falla, avisa con "Reintentar" y no pierde el texto', (
      tester,
    ) async {
      await open(
        tester,
        reviews: both,
        save: (_, _) async =>
            throw const ReviewServiceException('No se pudo guardar.'),
      );

      await openMenuAndPick(tester, 'Editar');
      await tester.enterText(find.byType(TextField), 'Texto que no se pierde');
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('Reintentar'), findsOneWidget);
      // La reseña de la lista no cambió mientras el servidor no confirmó.
      expect(find.text('Mi opinión original'), findsOneWidget);

      await openMenuAndPick(tester, 'Editar');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Texto que no se pierde');

      await unmount(tester);
    });
  });

  group('Eliminar desde la tarjeta', () {
    testWidgets('pide confirmación y "Cancelar" no borra', (tester) async {
      var deletes = 0;
      await open(tester, reviews: both, delete: (_) async => deletes++);

      await openMenuAndPick(tester, 'Eliminar');

      expect(find.text('¿Eliminar tu reseña?'), findsOneWidget);
      expect(
        find.text('Tu calificación y tu comentario se quitarán del negocio.'),
        findsOneWidget,
      );

      await tester.tap(dialogButton('Cancelar'));
      await settle(tester);
      await settle(tester);

      expect(deletes, 0);
      expect(find.text('Mi opinión original'), findsOneWidget);
      expect(find.byTooltip(_menuTooltip), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('al confirmar quita la tarjeta y actualiza todo al instante', (
      tester,
    ) async {
      var deletes = 0;
      await open(tester, reviews: both, delete: (_) async => deletes++);
      // Antes: (5 + 3) / 2 = 4.0 con 2 reseñas.
      expect(find.text('(2 reseñas)'), findsOneWidget);
      expect(find.text('4.0'), findsWidgets);
      expect(find.text('Editar mi reseña'), findsOneWidget);

      await openMenuAndPick(tester, 'Eliminar');
      await tester.tap(dialogButton('Eliminar'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(deletes, 1);
      expect(find.text('Eliminaste tu reseña'), findsOneWidget);
      expect(find.text('Mi opinión original'), findsNothing);
      expect(find.text('Opinión ajena'), findsOneWidget);
      expect(find.byTooltip(_menuTooltip), findsNothing);
      // Promedio, conteo y botón de arriba.
      expect(find.text('(1 reseñas)'), findsOneWidget);
      expect(find.text('3.0'), findsWidgets);
      expect(find.text('4.0'), findsNothing);
      expect(find.text('Escribir una reseña'), findsOneWidget);
      expect(find.text('Editar mi reseña'), findsNothing);

      await unmount(tester);
    });

    testWidgets('un segundo toque mientras se borra se ignora', (tester) async {
      var deletes = 0;
      final pending = Completer<void>();
      await open(
        tester,
        reviews: both,
        delete: (_) {
          deletes++;
          return pending.future;
        },
      );

      await openMenuAndPick(tester, 'Eliminar');
      await tester.tap(dialogButton('Eliminar'));
      await settle(tester);
      await settle(tester);
      expect(deletes, 1);

      // Con el borrado en curso, volver a elegir "Eliminar" no hace nada: ni
      // otro diálogo ni otro borrado.
      await openMenuAndPick(tester, 'Eliminar');
      expect(find.byType(AlertDialog), findsNothing);
      expect(deletes, 1);
      // La tarjeta sigue ahí hasta que el servidor confirme.
      expect(find.text('Mi opinión original'), findsOneWidget);

      pending.complete();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Mi opinión original'), findsNothing);
      expect(deletes, 1);

      await unmount(tester);
    });

    testWidgets('si falla, avisa con "Reintentar" y la tarjeta se queda', (
      tester,
    ) async {
      var deletes = 0;
      await open(
        tester,
        reviews: both,
        delete: (_) async {
          deletes++;
          if (deletes == 1) {
            throw const ReviewServiceException(
              'No tienes permiso para eliminar esta reseña. Inicia sesión de '
              'nuevo e intenta otra vez.',
            );
          }
        },
      );

      await openMenuAndPick(tester, 'Eliminar');
      await tester.tap(dialogButton('Eliminar'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(
        find.textContaining('No tienes permiso para eliminar'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Mi opinión original'), findsOneWidget);

      // "Reintentar" borra sin volver a pedir confirmación.
      await tester.tap(find.text('Reintentar'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(deletes, 2);
      expect(find.text('Mi opinión original'), findsNothing);
      expect(find.text('Eliminaste tu reseña'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('sin red avisa en español, sin texto técnico', (tester) async {
      await open(
        tester,
        reviews: both,
        delete: (_) async => throw TimeoutException('lento'),
      );

      await openMenuAndPick(tester, 'Eliminar');
      await tester.tap(dialogButton('Eliminar'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.textContaining('tardó demasiado'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Mi opinión original'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      await unmount(tester);
    });
  });

  group('Traducción de errores al eliminar', () {
    test('el permiso denegado (42501) habla de eliminar, no de guardar', () {
      final message = ReviewService.translateWriteError(
        const PostgrestException(message: 'rls', code: '42501'),
        deleting: true,
      );
      expect(message, contains('eliminar esta reseña'));
    });
  });
}
