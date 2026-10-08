import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/business/data/review_service.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_business_rating.dart';
import 'package:nikara_app/theme/app_theme.dart';

Widget _host(double average, int count, {double scale = 1}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: SizedBox(
        width: 170,
        child: MapBusinessRating(average: average, count: count),
      ),
    ),
  ),
);

void main() {
  testWidgets('muestra el promedio real y actualiza estrellas y cantidad', (
    tester,
  ) async {
    final reviews = [
      for (final rating in [4.0, 5.0])
        ReviewModel(
          id: '$rating',
          authorName: 'Viajero',
          rating: rating,
          comment: '',
          date: DateTime(2026),
        ),
    ];
    final summary = ReviewService.summarize(reviews);
    await tester.pumpWidget(_host(summary.average, summary.count));
    expect(find.text('4.5 · 2 reseñas'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    await tester.pumpWidget(_host(3, 1));
    expect(find.text('3.0 · 1 reseña'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin reseñas no inventa una puntuación', (tester) async {
    await tester.pumpWidget(_host(0, 0));
    expect(find.text('Sin reseñas'), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('admite texto grande y conteos largos en tarjetas pequeñas', (
    tester,
  ) async {
    await tester.pumpWidget(_host(4.2, 12345, scale: 1.6));
    expect(tester.takeException(), isNull);
  });
}
