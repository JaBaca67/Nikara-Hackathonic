import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/shared/widgets/detail_sections.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Nombre con descendentes ("g", "y") a propósito: la tarjeta flotante tapaba
/// justo la cola de esas letras, que es por donde se ve primero el solape.
BusinessModel _business({
  required String name,
  required String schedules,
  String category = 'Hospedaje',
  String subcategory = '',
}) => BusinessModel(
  id: 'layout-test',
  name: name,
  category: category,
  subcategory: subcategory,
  description: 'Descripción corta.',
  city: 'San Juan de Limay',
  locationText: 'Frente al parque central',
  latitude: 13.1,
  longitude: -86.4,
  contactPhone: '+505 8888 8888',
  hostName: 'José Alfredo',
  schedules: schedules,
  localImagePaths: const [],
);

const _sizes = [Size(360, 690), Size(390, 844)];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      // ignore: deprecated_member_use
      anonKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDetail(WidgetTester tester, BusinessModel business) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BusinessDetailScreen(business: business),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('el título de la portada no queda debajo de la tarjeta de '
      'datos rápidos', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const name = 'Hospedaje y Agroturismo Yegua Gris';
    final business = _business(
      name: name,
      schedules: 'Lunes a Domingo de 11:30 AM a 10:00 PM',
    );

    for (final size in _sizes) {
      await tester.binding.setSurfaceSize(size);
      await pumpDetail(tester, business);

      final title = tester.getRect(find.text(name));
      final card = tester.getRect(find.byType(DetailQuickInfoCard));
      // Margen real, no los 2px de antes: `AppTextStyles.detailTitle` usa
      // `height: 1.15`, más apretado que la caja natural de League Spartan,
      // así que los glifos se pintan fuera de su propia línea.
      expect(
        title.bottom + 8,
        lessThanOrEqualTo(card.top),
        reason:
            'el título toca la tarjeta flotante a ${size.width}x${size.height}',
      );
    }
  });

  testWidgets('el horario de la tarjeta se recorta a un rango, no a media '
      'frase', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_sizes.first);
    await pumpDetail(
      tester,
      _business(
        name: 'Hotel Patio del Malinche',
        schedules: 'Lunes a Domingo de 11:30 AM a 10:00 PM',
      ),
    );

    expect(find.text('11:30 AM – 10:00 PM'), findsOneWidget);
    expect(find.text('Horario'), findsOneWidget);
    // La frase completa sigue estando, pero en la sección "Horarios".
    expect(find.text('Lunes a Domingo de 11:30 AM a 10:00 PM'), findsOneWidget);
  });

  testWidgets('el formato estructurado del wizard nunca se muestra crudo', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_sizes.first);
    await pumpDetail(
      tester,
      _business(
        name: 'Hotel Patio del Malinche',
        schedules: '1,2,3,4,5: 07:00–18:00\n6,7: 06:00–19:00',
      ),
    );

    expect(find.textContaining('1,2,3,4,5'), findsNothing);
    expect(find.text('Lunes a Viernes · 7:00 AM – 6:00 PM'), findsOneWidget);
    expect(find.text('Sábado a Domingo · 6:00 AM – 7:00 PM'), findsOneWidget);
  });

  testWidgets('el pill de portada muestra la categoría normalizada', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_sizes.first);
    await pumpDetail(
      tester,
      _business(
        name: 'Reserva Natural Finca Kilimanjaro',
        schedules: '',
        // Como está guardado hoy en la base: nombre anterior del catálogo.
        category: 'Agroturismo / Fincas',
        subcategory: 'Finca cafetalera',
      ),
    );

    expect(find.text('Finca cafetalera · Agroturismo'), findsOneWidget);
    expect(find.textContaining('Agroturismo / Fincas'), findsNothing);
  });
}
