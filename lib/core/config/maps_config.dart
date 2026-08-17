/// Google Directions API key, for [DirectionsService]'s HTTP calls.
///
/// Deliberately separate from the Maps SDK key configured in
/// `android/local.properties` / `ios/Flutter/Maps.xcconfig` — those never
/// reach Dart code (they're consumed natively, see AndroidManifest.xml's
/// `${MAPS_API_KEY}` placeholder and AppDelegate.swift's `GMSApiKey`
/// lookup), so a Directions call from Dart needs its own value.
///
/// [directionsApiKey] resolves in two steps:
///  1. `--dart-define-from-file=dart_defines.json` (copy
///     `dart_defines.json.example`, drop in a real key) or the equivalent
///     inline `--dart-define=GOOGLE_MAPS_API_KEY=...`, if either was
///     passed at build/run time.
///  2. [_fallbackKey] otherwise — this is what actually runs "Cómo llegar"
///     out of the box for a plain `flutter run` with no flags, a fresh or
///     IDE-regenerated run config, CI, or a brand-new clone. This exists
///     because relying on step 1 alone caused this exact feature to break
///     — twice — the moment anyone launched the app any way other than
///     the one specific IDE run config that happened to carry the flag.
///
/// [_fallbackKey] is the *same* key already embedded, unobfuscated, in
/// every compiled Android APK for the native Maps SDK (see
/// `android/local.properties`'s `MAPS_API_KEY` / AndroidManifest.xml's
/// `com.google.android.geo.API_KEY` meta-data) — baking it here too
/// doesn't expose anything that isn't already shipped in the client
/// binary. In Google Cloud Console it needs "Directions API" enabled and,
/// per the note below, no "Android apps"/"iOS apps" restriction.
///
/// It CAN be the same key as the Maps SDK one as long as that key has no
/// "Android apps" / "iOS apps" restriction — those are enforced via
/// SDK-only request headers/bundle IDs that a plain HTTP call from Dart
/// never sends, so an app-restricted key gets REQUEST_DENIED here even
/// though it works fine for rendering the map itself. Prefer an HTTP
/// referrer or IP restriction (or none, for local hackathon-style
/// development) instead.
abstract class MapsConfig {
  static const _dartDefineKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static const _fallbackKey = 'AIzaSyBCwI7MElrFrMZgIGk_1mBZIwPUWhWzoT0';

  // `.isEmpty` isn't allowed in a const expression (only a handful of
  // String members are const-foldable) — `.length == 0` is.
  static const directionsApiKey = _dartDefineKey.length == 0
      ? _fallbackKey
      : _dartDefineKey;
}
