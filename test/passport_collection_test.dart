import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nikara_app/features/profile/domain/models/postcard_search.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';
import 'package:nikara_app/features/profile/presentation/screens/passport_collection_screen.dart';
import 'package:nikara_app/features/profile/presentation/widgets/passport_tab.dart';
import 'package:nikara_app/theme/app_theme.dart';

TravelPostcard card(
  int index, {
  String category = 'Restaurante',
  String? name,
  bool stamped = true,
}) => TravelPostcard(
  id: 'business-$index',
  title: name ?? 'Negocio $index',
  region: 'Granada',
  message: 'Una descripción real del negocio.',
  category: category,
  address: 'Dirección del negocio',
  sealedAt: stamped ? DateTime.utc(2026, 10, 7, 12, index) : null,
  latitude: 11.9293,
  longitude: -85.9525,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final postcards = [
    card(1, name: 'Restaurante El Zaguán'),
    card(2, name: 'Hotel Colonial', category: 'Hospedaje'),
    card(3, name: 'Taller Cerámico', category: 'Artesanía y Alfarería'),
    card(4, name: 'Mirador Laguna de Apoyo', category: 'Turismo y Miradores'),
  ];

  test('search handles accents, main category aliases and multiple terms', () {
    expect(searchPostcards(postcards, query: 'ZAGUAN').single.id, 'business-1');
    expect(searchPostcards(postcards, query: 'comida').single.id, 'business-1');
    expect(
      searchPostcards(postcards, query: 'cultura ceramico').single.id,
      'business-3',
    );
    expect(
      searchPostcards(postcards, category: 'Tours').single.id,
      'business-4',
    );
    expect(
      searchPostcards(postcards, query: 'hotel', category: 'Restaurante'),
      isEmpty,
    );
    expect(
      searchPostcards(
        postcards,
        query: '  hotel  ',
        category: 'Hospedaje',
      ).single.id,
      'business-2',
    );
  });

  test('collection keeps all earned postcards ordered, excluding previews', () {
    final many = List.generate(40, (index) => card(index));
    final results = searchPostcards([...many, card(41, stamped: false)]);
    expect(results, hasLength(40));
    expect(results.first.id, 'business-39');
    expect(results.last.id, 'business-0');
  });

  testWidgets(
    'profile previews the latest three and opens the full collection',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PassportTab(
                  postcards: postcards,
                  onViewAll: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PostcardThumbnail), findsNWidgets(3));
      expect(find.text('Restaurante El Zaguán'), findsNothing);
      await tester.ensureVisible(find.text('Ver todas las postales (4)'));
      await tester.tap(find.text('Ver todas las postales (4)'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search and category filters combine and reset without losing postcards',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PassportCollectionScreen(postcards: postcards),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zaguan');
      await tester.pumpAndSettle();
      expect(find.byType(PostcardThumbnail), findsOneWidget);
      expect(find.text('Restaurante El Zaguán'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Hospedaje'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hospedaje'));
      await tester.pumpAndSettle();
      expect(find.text('No encontramos postales'), findsOneWidget);
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(
        find.text('4 de 4 postales · Más recientes primero'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'cultura');
      await tester.pumpAndSettle();
      expect(find.byType(PostcardThumbnail), findsOneWidget);
      expect(find.text('Taller Cerámico'), findsOneWidget);
      await tester.tap(find.byType(PostcardThumbnail));
      await tester.pumpAndSettle();
      expect(find.byType(TravelPostcardCard), findsOneWidget);
      await tester.ensureVisible(find.text('Leer postal'));
      await tester.tap(find.text('Leer postal'));
      await tester.pumpAndSettle();
      expect(find.text('Querido viajero:'), findsOneWidget);
      expect(find.text('NÍKARA'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('collection remains usable at 320dp with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: PassportCollectionScreen(postcards: postcards),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zaguan');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Restaurante El Zaguán'));
      await tester.tap(find.text('Restaurante El Zaguán'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Leer postal'));
      await tester.tap(find.text('Leer postal'));
      await tester.pumpAndSettle();
      expect(find.text('Querido viajero:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all forty postcards remain reachable with lazy rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PassportCollectionScreen(postcards: List.generate(40, card)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PostcardThumbnail).evaluate().length, lessThan(40));
    await tester.scrollUntilVisible(
      find.text('Negocio 0'),
      300,
      maxScrolls: 40,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Negocio 0').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search remains usable with large text and an open keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: PassportCollectionScreen(postcards: postcards),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zaguan');
    await tester.pumpAndSettle();
    expect(
      find.text('1 de 4 postales · Más recientes primero'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
