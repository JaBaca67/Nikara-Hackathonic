/// Key para las llamadas HTTP de [DirectionsService]; separada de la key nativa del SDK de Maps porque esa nunca llega a Dart.
/// Si no se pasa `--dart-define`, usa [_fallbackKey] — depender solo del dart-define rompió "Cómo llegar" en runs sin ese flag.
/// [_fallbackKey] es la misma key ya embebida sin ofuscar en el APK nativo, así que no expone nada nuevo; solo funciona si no tiene restricción "Android apps"/"iOS apps" (esas restricciones bloquean llamadas HTTP planas desde Dart).
abstract class MapsConfig {
  static const _dartDefineKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static const _fallbackKey = 'AIzaSyBCwI7MElrFrMZgIGk_1mBZIwPUWhWzoT0';

  // `.isEmpty` no es const-foldable; `.length == 0` sí.
  static const directionsApiKey = _dartDefineKey.length == 0
      ? _fallbackKey
      : _dartDefineKey;
}
