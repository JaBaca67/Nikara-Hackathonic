/// Google Directions API key, for [DirectionsService]'s HTTP calls.
///
/// Deliberately separate from the Maps SDK key configured in
/// `android/local.properties` / `ios/Flutter/Maps.xcconfig` — those never
/// reach Dart code (they're consumed natively, see AndroidManifest.xml's
/// `${MAPS_API_KEY}` placeholder and AppDelegate.swift's `GMSApiKey`
/// lookup), so a Directions call from Dart needs its own key passed in at
/// build/run time instead, via a gitignored `dart_defines.json` at the repo
/// root (copy `dart_defines.json.example`, drop in a real key):
///
///   flutter run --dart-define-from-file=dart_defines.json
///
/// The Android Studio "main.dart" run config already passes this flag (see
/// `.idea/runConfigurations/main_dart.xml`), so running from the IDE picks
/// it up automatically — no per-run flag to remember. Without this file (or
/// the equivalent inline `--dart-define=GOOGLE_MAPS_API_KEY=...`),
/// [directionsApiKey] is empty and every "Cómo llegar" attempt fails with
/// [DirectionsServiceException]'s "ruta no configurada" message instead of
/// drawing a route — that's the #1 cause if navigation stops working after
/// a fresh clone or a new machine.
///
/// In Google Cloud Console, this key needs "Directions API" enabled. It CAN
/// be the same key as the Maps SDK one as long as that key has no
/// "Android apps" / "iOS apps" restriction — those are enforced via
/// SDK-only request headers/bundle IDs that a plain HTTP call from Dart
/// never sends, so an app-restricted key gets REQUEST_DENIED here even
/// though it works fine for rendering the map itself. Prefer an HTTP
/// referrer or IP restriction (or none, for local hackathon-style
/// development) instead.
abstract class MapsConfig {
  static const directionsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}
