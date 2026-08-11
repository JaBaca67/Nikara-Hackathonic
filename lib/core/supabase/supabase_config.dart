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
}