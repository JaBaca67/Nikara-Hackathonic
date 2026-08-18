import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/supabase/supabase_config.dart';

/// Enum simple a propósito (sin Bloc/Cubit): el proyecto usa servicios singleton + estado local (ver CLAUDE.md). [invalid] es solo del Form de la pantalla; [AuthService] nunca lo devuelve.
enum AuthStatus { idle, loading, success, error, invalid }

/// Resultado de un intento de sign-up/sign-in con [message] ya en español listo para un SnackBar.
class AuthResult {
  const AuthResult._({required this.status, this.message});

  const AuthResult.success() : this._(status: AuthStatus.success);

  const AuthResult.failure(String message)
    : this._(status: AuthStatus.error, message: message);

  /// El usuario cerró el selector de cuenta/consentimiento sin completar — no es un error real, por eso vuelve a [AuthStatus.idle] con `message` null.
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

/// Wrapper singleton sobre Supabase Auth + tabla `profiles`; no guarda nada más porque [GoTrueClient] ya persiste la sesión.
class AuthService {
  factory AuthService() => instance;

  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentAuthUser => _client.auth.currentUser;

  bool get isLoggedIn => currentAuthUser != null;

  /// Dispara en sign-in/sign-out/refresh de token; para reaccionar sin hacer polling de [currentAuthUser].
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<UserModel?> getCurrentProfile() async {
    final user = currentAuthUser;
    if (user == null) return null;
    return getProfileById(user.id);
  }

  /// Busca el perfil de cualquier usuario por id (p. ej. el dueño real de un negocio, no solo el viewer actual).
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

  /// La fila `profiles` la crea el trigger `on_auth_user_created` server-side, no este método; `role` deliberadamente no se envía para que un payload manipulado no pueda auto-asignarse otro rol.
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

  /// Google Sign-In → Supabase vía intercambio nativo de ID-token, sin redirect de navegador; requiere un cliente OAuth Web configurado (ver `SupabaseConfig`).
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
      // El trigger on_auth_user_created crea `profiles` server-side; lo comparten Google/Apple/Facebook sin duplicar lógica.
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e));
    } catch (_) {
      return const AuthResult.failure(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Solo iOS: Android soportaría Apple Sign-In vía redirect web, pero ese flujo no está configurado en el proyecto.
  bool get isAppleSignInSupported => !kIsWeb && Platform.isIOS;

  /// Apple Sign-In → Supabase, estructuralmente igual a [signInWithGoogle]; requiere capability en Xcode y Services ID (ver [SupabaseConfig.appleServiceId]).
  Future<AuthResult> signInWithApple() async {
    if (!isAppleSignInSupported) {
      return const AuthResult.failure(
        'Iniciar sesión con Apple solo está disponible en iOS por ahora.',
      );
    }
    try {
      // Nonce en texto plano a Apple (hasheado) y luego a Supabase (sin hashear): así Supabase verifica que el ID token es de este intento, no uno reusado.
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

      // Apple solo entrega givenName/familyName en la PRIMERA autorización; se hace backfill aquí porque el trigger no los ve.
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

  /// Facebook usa redirect de navegador (no ID-token nativo) porque su SDK Android no da un token OIDC verificable; [AuthResult.success] solo indica que el flujo se lanzó, no que terminó — el sign-in real llega después vía [authStateChanges].
  Future<AuthResult> signInWithFacebook() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: '${SupabaseConfig.oauthRedirectUrl}/',
        // 'rerequest' fuerza a Meta a mostrar el diálogo de nuevo; si no, recuerda un permiso denegado y no deja reintentar.
        queryParams: const {'auth_type': 'rerequest'},
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

  /// Promueve a 'emprendedor' vía RPC `promote_to_emprendedor` (no UPDATE directo: `role` ya no es escribible por el cliente); el chequeo local solo evita un round-trip innecesario, el RPC revalida igual.
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

  /// Borra la cuenta vía RPC `delete_own_user` (`security definer`, requiere privilegios que el cliente no tiene) y hace signOut local para no dejar tokens de una cuenta ya eliminada.
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_own_user');
    } on PostgrestException catch (e) {
      throw AuthServiceException('No se pudo eliminar tu cuenta: ${e.message}');
    } catch (_) {
      throw const AuthServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    await _client.auth.signOut();
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
