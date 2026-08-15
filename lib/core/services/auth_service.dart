import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/supabase/supabase_config.dart';

/// Explicit lifecycle of an Auth screen's in-flight action — kept as a
/// plain enum on purpose (no Bloc/Cubit/state-management package): this
/// project deliberately uses singleton services + local widget state (see
/// CLAUDE.md), so each screen just holds its own `AuthStatus` field the
/// same way it already held a `bool _isSubmitting`, and reacts to it in
/// `build()`. [invalid] is for the screen's own Form-validation failure —
/// [AuthService] never returns it, since it never sees a request that
/// didn't already pass local validation.
enum AuthStatus { idle, loading, success, error, invalid }

/// What a sign-up/sign-in attempt handed back — a friendly Spanish
/// [message] on failure, ready to drop straight into a SnackBar, instead of
/// callers having to interpret a raw [AuthException].
class AuthResult {
  const AuthResult._({required this.status, this.message});

  const AuthResult.success() : this._(status: AuthStatus.success);

  const AuthResult.failure(String message)
    : this._(status: AuthStatus.error, message: message);

  /// The user closed the Google account picker / backed out of the OS
  /// consent screen — not a real failure, so [status] resolves back to
  /// [AuthStatus.idle] and [message] stays null. Callers check
  /// `message == null` to skip showing an error SnackBar for an action the
  /// user chose themselves.
  const AuthResult.cancelled() : this._(status: AuthStatus.idle, message: null);

  final AuthStatus status;
  final String? message;

  bool get success => status == AuthStatus.success;
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Real Supabase Auth + `profiles` table — replaces the earlier local/mock
/// session system entirely. A thin singleton wrapper: Supabase's own
/// [GoTrueClient] already persists the session across app restarts, so
/// there's nothing else for this class to store.
class AuthService {
  factory AuthService() => instance;

  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentAuthUser => _client.auth.currentUser;

  bool get isLoggedIn => currentAuthUser != null;

  /// Fires on sign-in, sign-out, and token refresh — screens that need to
  /// react to auth state changing while mounted can listen to this instead
  /// of polling [currentAuthUser].
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<UserModel?> getCurrentProfile() async {
    final user = currentAuthUser;
    if (user == null) return null;
    return getProfileById(user.id);
  }

  /// Looks up any user's profile by id — e.g. to show a business's real
  /// owner, not just the signed-in viewer's own profile.
  Future<UserModel?> getProfileById(String id) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : UserModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw AuthServiceException('No se pudo cargar el perfil: ${e.message}');
    } catch (_) {
      throw const AuthServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Creates the `auth.users` row via Supabase Auth — the matching
  /// `profiles` row is created server-side by the `on_auth_user_created`
  /// trigger (see `supabase/sql/001_profiles_trigger_and_rls.sql`), not by
  /// this method. `fullName`/`phone` ride along as user metadata so the
  /// trigger can read them; `role` is deliberately NOT sent — the trigger
  /// always creates new accounts as 'turista' regardless of what's in
  /// metadata, so a crafted signUp payload can never grant itself a
  /// different role. A single round trip, and no "auth user exists but
  /// profile doesn't" half-created account if a second call had failed.
  Future<AuthResult> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone},
      );
      if (response.user == null) {
        return const AuthResult.failure(
          'No se pudo crear la cuenta. Intenta de nuevo.',
        );
      }
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e));
    } catch (_) {
      return const AuthResult.failure(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e));
    } catch (_) {
      return const AuthResult.failure(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Google Sign-In → Supabase, via the native ID-token exchange
  /// (`signInWithIdToken`) rather than a browser OAuth redirect — no
  /// extra deep-link/redirect-URL plumbing needed on mobile.
  ///
  /// Requires a Google OAuth **Web** client (its client ID goes in
  /// [GoogleSignIn.serverClientId] below) plus the matching platform
  /// client(s) registered with the same project, and the Google provider
  /// turned on in the Supabase dashboard with that same Web client ID/
  /// secret. That one-time console setup is outside this codebase — see
  /// `SupabaseConfig`'s doc comment for where the project's credentials
  /// live.
  ///
  /// Returns [AuthResult.cancelled] (no message) if the user backs out of
  /// the account picker — callers should skip showing an error SnackBar
  /// for that case specifically.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email'],
        serverClientId: SupabaseConfig.googleWebClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return const AuthResult.cancelled();

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return const AuthResult.failure(
          'No se pudo completar el inicio de sesión con Google.',
        );
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      // No manual `profiles` insert here — the `on_auth_user_created`
      // trigger (supabase/sql/001_profiles_trigger_and_rls.sql) creates it
      // server-side the first time this Google account signs in, reading
      // full_name straight from the ID token's own claims. Every provider
      // (Google/Apple/Facebook) shares that one trigger instead of each
      // duplicating this insert-if-missing logic.
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e));
    } catch (_) {
      return const AuthResult.failure(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Whether this device can offer native "Sign in with Apple" — iOS only
  /// for now. `sign_in_with_apple` technically supports Android too, but
  /// only via a web-redirect flow (a Services ID web configuration plus a
  /// deep link back into the app) this project hasn't set up; scoping to
  /// iOS keeps the button honest instead of shipping one that silently
  /// fails on Android. Callers (e.g. [SocialLoginRow]) should check this
  /// before even showing the Apple button on non-iOS.
  bool get isAppleSignInSupported => !kIsWeb && Platform.isIOS;

  /// Apple Sign-In → Supabase, via the native ID-token exchange —
  /// structurally the same as [signInWithGoogle]. Requires the "Sign in
  /// with Apple" capability added in Xcode (Runner target → Signing &
  /// Capabilities) and the Services ID configured in both Apple Developer
  /// and the Supabase dashboard — see [SupabaseConfig.appleServiceId]'s
  /// doc comment for the manual setup.
  ///
  /// The nonce dance below (raw nonce sent to Apple pre-hashed, the same
  /// raw nonce then sent to Supabase) is Supabase's own documented pattern
  /// for this exchange — it's what lets Supabase verify the ID token it
  /// receives is the exact one Apple issued for this specific sign-in
  /// attempt, not a replayed one.
  ///
  /// Returns [AuthResult.cancelled] if the user backs out of the Apple
  /// sheet.
  Future<AuthResult> signInWithApple() async {
    if (!isAppleSignInSupported) {
      return const AuthResult.failure(
        'Iniciar sesión con Apple solo está disponible en iOS por ahora.',
      );
    }
    try {
      final rawNonce = _client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return const AuthResult.failure(
          'No se pudo completar el inicio de sesión con Apple.',
        );
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      // Apple hands over givenName/familyName only on the very FIRST
      // authorization ever for this account — they're fields on this
      // native credential response, not part of the identityToken JWT, so
      // the on_auth_user_created trigger can never see them. Backfill
      // full_name here, this one time, while we still have them; every
      // sign-in after the first has both fields null and this is a no-op.
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part.isNotEmpty).join(' ');
      final user = currentAuthUser;
      if (fullName.isNotEmpty && user != null) {
        await _client
            .from('profiles')
            .update({'full_name': fullName})
            .eq('id', user.id);
      }

      return const AuthResult.success();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult.cancelled();
      }
      return const AuthResult.failure(
        'No se pudo completar el inicio de sesión con Apple.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e));
    } catch (_) {
      return const AuthResult.failure(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Facebook Login → Supabase. Unlike Google/Apple, this goes through the
  /// browser-redirect `signInWithOAuth` instead of a native ID-token
  /// exchange — Facebook's native Login SDK only returns a plain OAuth
  /// access token on Android (not an OIDC-signed ID token Supabase can
  /// verify client-side), and bridging that would need a server-side
  /// component this project doesn't have. See
  /// [SupabaseConfig.oauthRedirectUrl]'s doc comment for the deep-link
  /// setup this requires on both platforms.
  ///
  /// Opens a browser/custom-tab and suspends here — [AuthResult.success]
  /// only reflects that the flow *launched*, not that it finished; the
  /// actual sign-in completes asynchronously when the OS redirects back
  /// into the app and Supabase's [authStateChanges] fires. Callers should
  /// react to that stream (or [isLoggedIn] once resumed) rather than
  /// treating this method's return value as the final word — this mirrors
  /// how every other browser-based OAuth flow works, not a shortcut taken
  /// here specifically.
  Future<AuthResult> signInWithFacebook() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: '${SupabaseConfig.oauthRedirectUrl}/',
      );
      if (!launched) {
        return const AuthResult.failure(
          'No se pudo abrir la ventana de inicio de sesión con Facebook.',
        );
      }
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e));
    } catch (_) {
      return const AuthResult.failure(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Promotes the signed-in user's `profiles.role` to 'emprendedor' — called
  /// right after they successfully register their first business. Goes
  /// through the `promote_to_emprendedor` RPC (see
  /// `supabase/sql/001_profiles_trigger_and_rls.sql`) instead of a direct
  /// `UPDATE profiles SET role=...` — `role` isn't client-writable at the DB
  /// level anymore, and the RPC only ever flips turista->emprendedor
  /// server-side, so there's no client code path that can set any other
  /// role. The local read here is just to skip a pointless round trip for
  /// accounts that aren't 'turista' (an 'admin'/'auditor' registering a
  /// business keeps its elevated role) — the RPC re-checks the same
  /// condition itself regardless.
  Future<void> markAsEmprendedor() async {
    final user = currentAuthUser;
    if (user == null) return;
    try {
      final profile = await getProfileById(user.id);
      if (profile == null || profile.role != UserRole.turista) return;
      await _client.rpc('promote_to_emprendedor');
    } on PostgrestException catch (e) {
      throw AuthServiceException(
        'No se pudo actualizar tu perfil a emprendedor: ${e.message}',
      );
    } catch (_) {
      throw const AuthServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  String _friendlyAuthError(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'Ya existe una cuenta con este correo.';
    }
    if (message.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de iniciar sesión.';
    }
    if (message.contains('password')) {
      return 'La contraseña no cumple los requisitos mínimos (6+ caracteres).';
    }
    if (message.contains('email')) {
      return 'Correo no válido.';
    }
    return e.message;
  }
}
