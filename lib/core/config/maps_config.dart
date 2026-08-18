import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Key para las llamadas HTTP de [DirectionsService]; separada de la key nativa del SDK de Maps porque esa nunca llega a Dart.
/// Se lee en tiempo de ejecución desde `.env` (cargado en `main.dart` vía `dotenv.load`) — nunca hardcodeada en el código fuente.
abstract class MapsConfig {
  static String get directionsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
}
