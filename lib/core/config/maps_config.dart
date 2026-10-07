import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Clave de Google Maps leída de `.env` (cargado en `main.dart` vía `dotenv.load`) — nunca hardcodeada en el código fuente.
///
/// Esta clave solo sirve para las llamadas HTTP de [DirectionsService]. El SDK
/// nativo del mapa en Android lee la suya del manifiesto (que Gradle arma desde
/// `android/local.properties`), y nunca pasa por Dart: que esta clave exista no
/// prueba que el mapa nativo la tenga, por eso conviene que sea la misma.
abstract class MapsConfig {
  /// Nombre canónico en `.env`; es el mismo que usa `android/local.properties`.
  static const _envKey = 'MAPS_API_KEY';

  /// Nombre anterior; se sigue aceptando para no romper un `.env` viejo.
  static const _legacyEnvKey = 'GOOGLE_MAPS_API_KEY';

  /// Vacía si `.env` no cargó o la variable no existe — nunca lanza (los
  /// widget tests no cargan `.env` y `dotenv.env` lanzaría sin inicializar).
  static String get apiKey {
    if (!dotenv.isInitialized) return '';
    final value = dotenv.env[_envKey] ?? dotenv.env[_legacyEnvKey] ?? '';
    return value.trim();
  }

  static bool get hasApiKey => apiKey.isNotEmpty;

  static String get directionsApiKey => apiKey;
}
