/// Credenciales del proyecto Supabase; el anon key es público a propósito (RLS deshabilitado en este proyecto) — el service_role key nunca debe aparecer aquí.
abstract class SupabaseConfig {
  /// URL base del proyecto, NO el endpoint REST — `Supabase.initialize` ya arma `/rest/v1/`, `/auth/v1/`, etc. sobre esto.
  static const url = 'https://taxtvsqfpmrrkvezwwpb.supabase.co';

  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRheHR2c3FmcG1ycmt2ZXp3d3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxMDk0NjIsImV4cCI6MjEwMTY4NTQ2Mn0.oMe1SIaSjZpa7jinnh5MLuLdfJHTdTVSM2KCy_gAa-I';

  /// Debe ser el Web client ID de Google Cloud Console (no el de Android/iOS): Supabase valida el `aud` del token contra este mismo valor configurado en su dashboard.
  static const googleWebClientId =
      '736353638754-c347fou9tj977ci3a8n96i89r85tvpls.apps.googleusercontent.com';

  /// El Services ID (no el App ID) registrado para "Sign in with Apple" — Supabase valida el `aud` del token contra este valor.
  static const appleServiceId = 'REPLACE_WITH_APPLE_SERVICES_ID';

  // Facebook no tiene un SDK nativo que dé un ID token verificable en Android, por eso [AuthService.signInWithFacebook] usa redirect de navegador vía Supabase en vez de exchange nativo.

  /// A dónde redirige Supabase tras un OAuth por navegador (solo Facebook lo usa); debe coincidir exacto con el intent-filter de Android, `CFBundleURLSchemes` de iOS y el allow-list del dashboard de Supabase.
  static const oauthRedirectUrl = 'io.nikara.app://login-callback';
}
