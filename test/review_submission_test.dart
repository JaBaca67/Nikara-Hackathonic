import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _kSend = 'Enviar reseña';

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

  group('WriteReviewSheet: envío', () {
    /// Abre la hoja desde un botón, como en la app, para poder comprobar si
    /// se cerró. [onSubmit] decide cuánto tarda y cómo termina el envío.
    Future<void> openSheet(
      WidgetTester tester, {
      required Future<bool?> Function(ReviewDraft) onSubmit,
      ReviewDraft? initialDraft,
      bool autoSubmit = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => WriteReviewSheet(
                      onSubmit: onSubmit,
                      initialDraft: initialDraft,
                      autoSubmit: autoSubmit,
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await settle(tester);
      await settle(tester);
    }

    bool sheetIsOpen() => find.byType(WriteReviewSheet).evaluate().isNotEmpty;

    AppLoadingButton sendButton(WidgetTester tester) =>
        tester.widget<AppLoadingButton>(find.byType(AppLoadingButton));

    testWidgets('un segundo toque mientras se publica no envía otra reseña', (
      tester,
    ) async {
      final completer = Completer<bool?>();
      var calls = 0;
      await openSheet(
        tester,
        onSubmit: (_) {
          calls++;
          return completer.future;
        },
      );

      await tester.enterText(find.byType(TextField), 'Muy buena atención');
      await tester.pump();
      await tester.tap(find.text(_kSend));
      await settle(tester);
      // Un frame más: la transición etiqueta → spinner arranca en el frame
      // que reconstruye el botón.
      await settle(tester);

      // En curso: spinner dentro del botón Enviar, que ya no tiene etiqueta.
      expect(calls, 1);
      expect(
        find.descendant(
          of: find.byType(AppLoadingButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text(_kSend), findsNothing);

      // Otro toque sobre el botón no dispara una segunda publicación.
      await tester.tap(find.byType(AppLoadingButton), warnIfMissed: false);
      await settle(tester);
      expect(calls, 1);

      // Tampoco se puede cerrar la hoja a medio publicar.
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(sheetIsOpen(), isTrue);

      completer.complete(true);
      await settle(tester);
      await settle(tester);
      expect(sheetIsOpen(), isFalse);
      expect(calls, 1);
    });

    testWidgets('si falla, la hoja se cierra y no queda nada bloqueado', (
      tester,
    ) async {
      var calls = 0;
      await openSheet(
        tester,
        onSubmit: (_) async {
          calls++;
          return false;
        },
      );

      await tester.enterText(find.byType(TextField), 'Muy buena atención');
      await tester.pump();
      await tester.tap(find.text(_kSend));
      await settle(tester);
      await settle(tester);

      expect(calls, 1);
      expect(sheetIsOpen(), isFalse);
    });

    testWidgets('si se ignora la llamada, el botón se vuelve a habilitar', (
      tester,
    ) async {
      await openSheet(tester, onSubmit: (_) async => null);

      await tester.enterText(find.byType(TextField), 'Muy buena atención');
      await tester.pump();
      await tester.tap(find.text(_kSend));
      await settle(tester);

      expect(sheetIsOpen(), isTrue);
      expect(find.text(_kSend), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('sin comentario no envía y avisa', (tester) async {
      var calls = 0;
      await openSheet(
        tester,
        onSubmit: (_) async {
          calls++;
          return true;
        },
      );

      await tester.tap(find.text(_kSend));
      await settle(tester);

      expect(calls, 0);
      expect(
        find.text('Escribe un comentario antes de enviar'),
        findsOneWidget,
      );
      expect(sheetIsOpen(), isTrue);
    });

    testWidgets('con una reseña fallida se abre prellenada', (tester) async {
      await openSheet(
        tester,
        onSubmit: (_) async => true,
        initialDraft: const ReviewDraft(
          rating: 3,
          comment: 'Lo que escribí antes',
          mediaPaths: [],
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Lo que escribí antes');
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    });

    testWidgets('"Reintentar" reenvía solo, con el spinner en Enviar', (
      tester,
    ) async {
      final completer = Completer<bool?>();
      ReviewDraft? sent;
      await openSheet(
        tester,
        onSubmit: (draft) {
          sent = draft;
          return completer.future;
        },
        initialDraft: const ReviewDraft(
          rating: 4,
          comment: 'Lo que escribí antes',
          mediaPaths: [],
        ),
        autoSubmit: true,
      );

      expect(sent?.comment, 'Lo que escribí antes');
      expect(sent?.rating, 4);
      expect(
        find.descendant(
          of: find.byType(AppLoadingButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      completer.complete(true);
      await settle(tester);
      await settle(tester);
      expect(sheetIsOpen(), isFalse);
    });
  });

  group('BusinessDetailScreen: reseña sin poder publicar', () {
    final business = BusinessModel(
      id: 'review-test-id',
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
    );

    Future<void> openReviewsTab(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BusinessDetailScreen(business: business),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Reseñas & Fotos'));
      await settle(tester);
    }

    Finder writeButton() =>
        find.widgetWithText(OutlinedButton, 'Escribir una reseña');

    Future<void> unmount(WidgetTester tester) async {
      // Las pantallas con Realtime agendan un timer de desconexión al cerrar.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    }

    testWidgets('avisa en español con "Reintentar" y conserva el texto', (
      tester,
    ) async {
      await openReviewsTab(tester);

      await tester.tap(writeButton());
      await settle(tester);
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Muy buena atención');
      await tester.pump();
      await tester.tap(find.text(_kSend));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Sin sesión no se puede publicar: la hoja se cierra y sale el aviso.
      expect(find.byType(WriteReviewSheet), findsNothing);
      expect(
        find.text('Inicia sesión para escribir una reseña.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      // El botón "Escribir una reseña" no se queda con un spinner ni bloqueado.
      expect(
        find.descendant(
          of: writeButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(tester.widget<OutlinedButton>(writeButton()).onPressed, isNotNull);

      // Al abrir otra vez, el texto que escribió sigue ahí.
      await tester.tap(writeButton());
      await settle(tester);
      await settle(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Muy buena atención');

      await unmount(tester);
    });

    testWidgets('"Reintentar" vuelve a enviar la misma reseña', (tester) async {
      await openReviewsTab(tester);

      await tester.tap(writeButton());
      await settle(tester);
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Muy buena atención');
      await tester.pump();
      await tester.tap(find.text(_kSend));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Reintentó (la hoja se abrió, envió sola y volvió a fallar por la
      // misma razón) y el aviso con su botón sigue disponible.
      expect(find.byType(WriteReviewSheet), findsNothing);
      expect(
        find.text('Inicia sesión para escribir una reseña.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      await unmount(tester);
    });
  });
}
