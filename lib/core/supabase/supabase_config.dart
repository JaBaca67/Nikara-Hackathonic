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
      'REPLACE_WITH_GOOGLE_CLOUD_WEB_CLIENT_ID.apps.googleusercontent.com';
}
