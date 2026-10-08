import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/utils/spanish_date_format.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
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

  group('formatShortDateTime', () {
    test('formato en español con mes abreviado y hora de 12 horas', () {
      expect(
        formatShortDateTime(DateTime(2026, 10, 8, 15, 17)),
        '8 oct 2026 · 3:17 p. m.',
      );
      expect(
        formatShortDateTime(DateTime(2026, 1, 31, 9, 5)),
        '31 ene 2026 · 9:05 a. m.',
      );
    });

    test('medianoche y mediodía usan 12, no 0', () {
      expect(
        formatShortDateTime(DateTime(2026, 3, 1, 0, 0)),
        '1 mar 2026 · 12:00 a. m.',
      );
      expect(
        formatShortDateTime(DateTime(2026, 3, 1, 12, 30)),
        '1 mar 2026 · 12:30 p. m.',
      );
    });

    test('los doce meses salen abreviados en español', () {
      final months = [
        for (var m = 1; m <= 12; m++)
          formatShortDateTime(DateTime(2026, m, 2, 10)).split(' ')[1],
      ];
      expect(months, [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ]);
    });

    test('una fecha UTC se convierte a la hora local del teléfono', () {
      final utc = DateTime.utc(2026, 10, 9, 1, 17);
      final local = utc.toLocal();
      final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final text = formatShortDateTime(utc);

      // Mismo instante que su versión local, y los campos son los locales
      // (que pueden caer incluso en otro día que el UTC).
      expect(text, formatShortDateTime(local));
      expect(text, startsWith('${local.day} '));
      expect(text, contains(' ${local.year} · $hour12:17 '));
    });

    test('sin fecha no se rompe: devuelve cadena vacía', () {
      expect(formatShortDateTime(null), '');
    });
  });

  group('Tarjeta de reseña', () {
    final review = ReviewModel(
      id: '1',
      authorId: 'otra',
      authorName: 'Una persona con un nombre bastante largo para forzar',
      rating: 4,
      comment: 'Muy buen lugar',
      date: DateTime(2026, 10, 8, 15, 17),
    );

    final business = BusinessModel(
      id: 'review-date-test',
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
      reviews: [review],
    );

    Future<void> open(
      WidgetTester tester, {
      required Size size,
      double textScale = 1,
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: BusinessDetailScreen(business: business),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Reseñas & Fotos'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    }

    testWidgets('muestra la fecha y la hora de publicación', (tester) async {
      await open(tester, size: const Size(390, 1200));
      expect(find.text('8 oct 2026 · 3:17 p. m.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
      'en pantalla chica y con texto grande queda dentro de la tarjeta',
      (tester) async {
        await open(tester, size: const Size(320, 1200), textScale: 2);

        // Con texto al doble, otras partes de esta pantalla (el rótulo de la
        // portada, por ejemplo) ya desbordan de antes y no son de este cambio:
        // se descartan para medir solo la tarjeta de la reseña.
        while (tester.takeException() != null) {}

        final date = find.textContaining('8 oct 2026');
        expect(date, findsOneWidget);
        final card = find.ancestor(
          of: date,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        final dateRect = tester.getRect(date);
        final cardRect = tester.getRect(card.first);
        expect(dateRect.left, greaterThanOrEqualTo(cardRect.left));
        expect(dateRect.right, lessThanOrEqualTo(cardRect.right));
        // Puede bajar de línea, pero nunca se corta.
        final paragraph = tester.renderObject<RenderParagraph>(date);
        expect(paragraph.didExceedMaxLines, isFalse);
        await unmount(tester);
      },
    );
  });
}
