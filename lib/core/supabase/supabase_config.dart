/// Supabase project credentials.
///
/// The anon key is meant to ship inside the compiled client app — Supabase
/// relies on Row Level Security (or, for this project, RLS being
/// deliberately disabled) rather than key secrecy to control access, unlike
/// a service_role key which must never appear here.
abstract class SupabaseConfig {
  /// Base project URL — NOT the REST endpoint. `Supabase.initialize` builds
  /// `/rest/v1/`, `/auth/v1/`, etc. on top of this itself, so passing the
  /// full `.../rest/v1/` URL would double up the path on every request.
  static const url = 'https://taxtvsqfpmrrkvezwwpb.supabase.co';

  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRheHR2c3FmcG1ycmt2ZXp3d3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxMDk0NjIsImV4cCI6MjEwMTY4NTQ2Mn0.oMe1SIaSjZpa7jinnh5MLuLdfJHTdTVSM2KCy_gAa-I';

  /// OAuth 2.0 **Web** client ID from Google Cloud Console — required so
  /// `GoogleSignIn` requests an ID token audience-scoped to match what the
  /// Supabase dashboard's Google provider expects (Supabase validates the
  /// token's `aud` claim against the Web client ID configured there, not
  /// the platform-specific Android/iOS client). Safe to ship in the client
  /// like [anonKey] — this is a public identifier, not a secret.
  ///
  /// PENDING MANUAL SETUP (outside this codebase):
  /// 1. Google Cloud Console → create an OAuth "Web application" client
  ///    (plus Android/iOS clients using this app's real package
  ///    name/bundle id and SHA-1, if not already present).
  /// 2. Supabase dashboard → Authentication → Providers → Google → paste
  ///    that Web client's ID + secret, toggle it on.
  /// 3. Replace the placeholder below with that same Web client ID.
  static const googleWebClientId =
      '736353638754-c347fou9tj977ci3a8n96i89r85tvpls.apps.googleusercontent.com';

  /// The Services ID (not the App ID) registered for "Sign in with Apple"
  /// — the identifier Supabase's Apple provider checks the ID token's
  /// `aud` claim against. Safe to ship in the client, same reasoning as
  /// [googleWebClientId].
  ///
  /// PENDING MANUAL SETUP (outside this codebase):
  /// 1. Apple Developer account → Certificates, Identifiers & Profiles →
  ///    turn on "Sign in with Apple" for this app's existing App ID.
  /// 2. Create a separate **Services ID** (e.g. `com.nikara.app.signin`) —
  ///    this, not the App ID, is the value that goes below.
  /// 3. Supabase dashboard → Authentication → Providers → Apple → paste
  ///    that Services ID (+ the Team ID / Key ID / private key from a
  ///    Sign in with Apple key, generated in the same Apple Developer
  ///    section), toggle it on.
  /// 4. Xcode → Runner target → Signing & Capabilities → add the
  ///    "Sign in with Apple" capability (native iOS entitlement — the
  ///    `sign_in_with_apple` package needs this regardless of the Services
  ///    ID above).
  static const appleServiceId = 'REPLACE_WITH_APPLE_SERVICES_ID';

  /// Facebook has no clean native "give me an ID token" SDK path on
  /// Android the way Google/Apple do (its Login SDK only ever returns a
  /// plain OAuth access token there, not an OIDC-signed one Supabase can
  /// verify client-side) — bridging that would need a server component
  /// (an Edge Function holding the service_role key) this project doesn't
  /// have. So [AuthService.signInWithFacebook] goes through Supabase's
  /// browser-redirect `signInWithOAuth` instead, which needs no Facebook
  /// SDK or App ID in this app at all — Supabase holds the Facebook App
  /// ID/Secret itself and does the whole OAuth dance server-side. This app
  /// only needs to open that URL and catch the redirect back, via
  /// [oauthRedirectUrl] — see its own doc comment for the platform setup
  /// that requires.
  ///
  /// PENDING MANUAL SETUP (outside this codebase):
  /// 1. developers.facebook.com → create an app → add the "Facebook Login"
  ///    product → Settings → Valid OAuth Redirect URIs → add this
  ///    project's Supabase callback: `https://taxtvsqfpmrrkvezwwpb.supabase.co/auth/v1/callback`
  ///    (Supabase's own URL, not [oauthRedirectUrl] — that one is what
  ///    Supabase redirects BACK to, after it, once it already has a
  ///    session).
  /// 2. Copy that app's App ID + App Secret into: Supabase dashboard →
  ///    Authentication → Providers → Facebook, toggle it on.

  /// Where Supabase redirects back into this app after ANY browser-based
  /// OAuth flow finishes (currently only [AuthService.signInWithFacebook]
  /// uses this — Google/Apple use native id-token exchanges and never
  /// leave the app). Must exactly match:
  /// - the intent-filter `android:scheme`/`android:host` in
  ///   `android/app/src/main/AndroidManifest.xml`,
  /// - the `CFBundleURLSchemes` entry in `ios/Runner/Info.plist`,
  /// - and the "Redirect URLs" allow-list in the Supabase dashboard
  ///   (Authentication → URL Configuration).
  /// Not a secret — it's just this app's own deep-link address.
  static const oauthRedirectUrl = 'io.nikara.app://login-callback';
}
