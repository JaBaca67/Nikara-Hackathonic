import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/config/maps_config.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Claves falsas: ningún test toca ni necesita la clave real.
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
    dotenv.clean();
  });

  tearDown(dotenv.clean);

  group('MapsConfig', () {
    test('sin .env cargado no lanza y reporta clave ausente', () {
      expect(dotenv.isInitialized, isFalse);
      expect(MapsConfig.apiKey, isEmpty);
      expect(MapsConfig.hasApiKey, isFalse);
    });

    test('lee MAPS_API_KEY', () {
      dotenv.loadFromString(envString: 'MAPS_API_KEY=fake-key-123');
      expect(MapsConfig.apiKey, 'fake-key-123');
      expect(MapsConfig.directionsApiKey, 'fake-key-123');
      expect(MapsConfig.hasApiKey, isTrue);
    });

    test('sigue aceptando el nombre anterior GOOGLE_MAPS_API_KEY', () {
      dotenv.loadFromString(envString: 'GOOGLE_MAPS_API_KEY=legacy-key');
      expect(MapsConfig.apiKey, 'legacy-key');
    });

    test('MAPS_API_KEY gana sobre el nombre anterior', () {
      dotenv.loadFromString(
        envString: 'GOOGLE_MAPS_API_KEY=legacy-key\nMAPS_API_KEY=new-key',
      );
      expect(MapsConfig.apiKey, 'new-key');
    });

    test('una clave vacía o de solo espacios cuenta como ausente', () {
      dotenv.loadFromString(envString: 'MAPS_API_KEY=   ');
      expect(MapsConfig.hasApiKey, isFalse);
    });
  });

  group('MapScreen sin clave', () {
    Future<void> pumpMap(WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const MapScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    }

    testWidgets('avisa con un mensaje claro en español', (tester) async {
      await pumpMap(tester);
      expect(
        find.textContaining('El mapa no está configurado'),
        findsOneWidget,
      );
      expect(find.textContaining('MAPS_API_KEY'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('con clave definida no muestra el aviso', (tester) async {
      dotenv.loadFromString(envString: 'MAPS_API_KEY=fake-key-123');
      await pumpMap(tester);
      expect(find.textContaining('El mapa no está configurado'), findsNothing);
      await unmount(tester);
    });
  });
}
