import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/directions_service.dart';

void main() {
  late http.Request request;
  int responseStatus = 200;
  Map<String, dynamic> response = {};

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode(response),
          responseStatus,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  setUp(() {
    responseStatus = 200;
    response = {
      'status': 'OK',
      'routes': [
        {
          'legs': [
            {
              'distance': {'value': 1200},
              'duration': {'value': 600},
              'steps': [
                {
                  'start_location': {'lat': 12.0, 'lng': -86.0},
                  'end_location': {'lat': 12.01, 'lng': -86.01},
                  'distance': {'value': 1200},
                  'duration': {'value': 600},
                  'html_instructions': 'Continúa recto',
                },
              ],
            },
          ],
        },
      ],
    };
  });

  Future<DirectionsRoute> route() => DirectionsService().getRoute(
    origin: const LatLng(12, -86),
    destination: const LatLng(12.01, -86.01),
    mode: TravelMode.walking,
  );

  test(
    'calcula la ruta mediante Supabase sin clave de Google en el cliente',
    () async {
      final result = await route();
      expect(request.url.path, '/functions/v1/get-directions');
      expect(request.url.host, 'example.supabase.co');
      expect(jsonDecode(request.body), {
        'origin': {'lat': 12.0, 'lng': -86.0},
        'destination': {'lat': 12.01, 'lng': -86.01},
        'mode': 'walking',
      });
      expect(result.distanceMeters, 1200);
      expect(result.durationSeconds, 600);
      expect(result.points, [
        const LatLng(12, -86),
        const LatLng(12.01, -86.01),
      ]);
    },
  );

  test('conserva el mensaje en español enviado por la función', () async {
    responseStatus = 503;
    response = {'error': 'No se pudo calcular la ruta en este momento.'};
    await expectLater(
      route(),
      throwsA(
        isA<DirectionsServiceException>().having(
          (error) => error.message,
          'message',
          response['error'],
        ),
      ),
    );
  });

  test('una respuesta sin rutas se traduce a un error comprensible', () async {
    response = {'status': 'OK', 'routes': []};
    await expectLater(
      route(),
      throwsA(
        isA<DirectionsServiceException>().having(
          (error) => error.message,
          'message',
          'No se encontró una ruta hasta este lugar.',
        ),
      ),
    );
  });
}
