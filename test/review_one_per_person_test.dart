import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/business/data/review_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

ReviewModel _review(
  String id,
  String author,
  double rating, {
  int daysAgo = 0,
  String comment = 'ok',
}) => ReviewModel(
  id: id,
  authorId: author,
  authorName: author,
  rating: rating,
  comment: comment,
  date: DateTime(2026, 10, 10).subtract(Duration(days: daysAgo)),
);

BusinessModel _business(List<ReviewModel> reviews) => BusinessModel(
  id: 'b1',
  name: 'Café',
  category: 'Café',
  description: 'd',
  city: 'León',
  locationText: 'Centro',
  contactPhone: '',
  hostName: 'Ana',
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

  group('Promedio y conteo: una reseña por persona', () {
    test('varias reseñas de la misma persona cuentan como una (la última)', () {
      final reviews = [
        _review('1', 'ana', 1, daysAgo: 5),
        _review('2', 'ana', 5, daysAgo: 1),
        _review('3', 'ana', 3, daysAgo: 3),
        _review('4', 'luis', 3),
      ];

      final counted = onePerAuthor(reviews);
      expect(counted.map((r) => r.id), ['2', '4']);

      final business = _business(reviews);
      expect(business.reviewCount, 2);
      expect(business.averageRating, 4); // (5 + 3) / 2, no (1+5+3+3) / 4
    });

    test('sin duplicados no cambia nada y sin reseñas el promedio es 0', () {
      final reviews = [_review('1', 'ana', 4), _review('2', 'luis', 2)];
      expect(onePerAuthor(reviews), reviews);
      expect(_business(reviews).averageRating, 3);
      expect(_business(const []).reviewCount, 0);
      expect(_business(const []).averageRating, 0);
    });

    test('las reseñas sin autor identificado no se fusionan', () {
      final reviews = [_review('1', '', 5), _review('2', '', 1)];
      expect(onePerAuthor(reviews), hasLength(2));
    });

    test('el resumen del dashboard también cuenta una por persona', () {
      final summary = ReviewService.summarize([
        _review('1', 'ana', 1, daysAgo: 2),
        _review('2', 'ana', 5),
        _review('3', 'luis', 3),
      ]);
      expect(summary.count, 2);
      expect(summary.average, 4);
    });
  });

  group('Crear o editar: nunca dos reseñas de la misma persona', () {
    test('una persona nueva se agrega', () {
      final result = upsertReviewByAuthor([
        _review('1', 'ana', 4),
      ], _review('2', 'luis', 3));
      expect(result.map((r) => r.authorId), ['ana', 'luis']);
    });

    test('editar reemplaza la reseña existente en su misma posición', () {
      final before = [
        _review('1', 'ana', 4),
        _review('2', 'luis', 3),
        _review('3', 'rosa', 5),
      ];
      final edited = _review('2', 'luis', 1, comment: 'cambié de opinión');

      final after = upsertReviewByAuthor(before, edited);

      expect(after, hasLength(3));
      expect(after.map((r) => r.authorId), ['ana', 'luis', 'rosa']);
      expect(after[1].rating, 1);
      expect(after[1].comment, 'cambié de opinión');
    });

    test('guardar dos veces seguidas deja una sola reseña', () {
      var reviews = <ReviewModel>[];
      reviews = upsertReviewByAuthor(reviews, _review('1', 'ana', 5));
      reviews = upsertReviewByAuthor(reviews, _review('1', 'ana', 2));
      expect(reviews, hasLength(1));
      expect(_business(reviews).averageRating, 2);
    });
  });

  group('Eliminar la reseña propia', () {
    test('quita la reseña de la persona y deja las demás', () {
      final after = removeReviewsByAuthor([
        _review('1', 'ana', 5),
        _review('2', 'luis', 3),
      ], 'ana');
      expect(after.map((r) => r.authorId), ['luis']);
      expect(_business(after).averageRating, 3);
      expect(_business(after).reviewCount, 1);
    });
  });

  group('Errores de escritura traducidos', () {
    test('la unicidad (23505) se explica en español', () {
      final message = ReviewService.translateWriteError(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(message, contains('Ya calificaste este lugar'));
    });

    test('un permiso denegado (42501) se explica en español', () {
      final message = ReviewService.translateWriteError(
        const PostgrestException(message: 'rls', code: '42501'),
      );
      expect(message, contains('No tienes permiso'));
    });

    test('un código desconocido no se traduce (queda el mensaje genérico)', () {
      expect(
        ReviewService.translateWriteError(
          const PostgrestException(message: 'x', code: 'XX000'),
        ),
        isNull,
      );
    });
  });

  group('WriteReviewSheet al editar', () {
    Future<void> open(WidgetTester tester, {required bool isEditing}) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WriteReviewSheet(
                isEditing: isEditing,
                initialDraft: isEditing
                    ? const ReviewDraft(
                        rating: 2,
                        comment: 'Mi comentario anterior',
                        mediaPaths: [],
                      )
                    : null,
                onSubmit: (_) async => true,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('abre con la calificación y el comentario actuales', (
      tester,
    ) async {
      await open(tester, isEditing: true);
      expect(find.text('Editar mi reseña'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('Mi comentario anterior'), findsOneWidget);
      expect(find.text('Enviar reseña'), findsNothing);
    });

    testWidgets('sin reseña previa sigue siendo "Escribir una reseña"', (
      tester,
    ) async {
      await open(tester, isEditing: false);
      expect(find.text('Escribir una reseña'), findsOneWidget);
      expect(find.text('Enviar reseña'), findsOneWidget);
      expect(find.text('Editar mi reseña'), findsNothing);
    });
  });
}
