/// Google Directions API key, for [DirectionsService]'s HTTP calls.
///
/// Deliberately separate from the Maps SDK key configured in
/// `android/local.properties` / `ios/Flutter/Maps.xcconfig` — those never
/// reach Dart code (they're consumed natively, see AndroidManifest.xml's
/// `${MAPS_API_KEY}` placeholder and AppDelegate.swift's `GMSApiKey`
/// lookup), so a Directions call from Dart needs its own key passed in at
/// build/run time instead:
///
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
///
/// In Google Cloud Console, this key should have "Directions API" enabled
/// and be restricted by HTTP referrer/IP as appropriate for how the app is
/// distributed — do NOT reuse an Android/iOS-app-restricted key here, since
/// those restrictions are enforced via SDK-only request headers that a
/// plain HTTP call from Dart doesn't send.
abstract class MapsConfig {
  static const directionsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}
