import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/saved_account.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/account_switcher_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/utils/image_upload.dart';
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

  /// Cerrar sesión de verdad: Supabase revoca el refresh token, así que la
  /// entrada guardada de esta cuenta ya no serviría para volver a ella y se
  /// borra. Las demás cuentas guardadas sobreviven, que es justo el punto del
  /// selector.
  Future<void> signOut() async {
    final userId = currentAuthUser?.id;
    if (userId != null) {
      await _accounts.remove(userId);
    }
    await _client.auth.signOut();
    FavoritesService().invalidate();
  }

  // ==================== Cambio rápido de cuentas ====================

  AccountSwitcherService get _accounts => AccountSwitcherService();

  StreamSubscription<AuthState>? _sessionTrackerSub;

  /// Cuentas guardadas distintas de la activa, listas para [switchAccount].
  Future<List<SavedAccount>> getSavedAccounts() async {
    final accounts = await _accounts.getAccounts();
    final currentId = currentAuthUser?.id;
    return accounts.where((a) => a.userId != currentId).toList(growable: false);
  }

  Future<void> forgetAccount(String userId) => _accounts.remove(userId);

  /// Empieza a persistir la sesión activa en cada `signedIn` /
  /// `tokenRefreshed` / `userUpdated`. Se llama una sola vez desde `main()`,
  /// después de `Supabase.initialize`.
  ///
  /// Va por el stream y no por cada método de login porque los tres proveedores
  /// OAuth, el login por contraseña y el propio [switchAccount] terminan todos
  /// en el mismo evento — y porque los refresh tokens rotan: sin escuchar
  /// `tokenRefreshed`, la entrada guardada quedaría obsoleta a la hora.
  void startTrackingSessions() {
    _sessionTrackerSub ??= authStateChanges.listen((state) {
      const tracked = {
        AuthChangeEvent.signedIn,
        AuthChangeEvent.tokenRefreshed,
        AuthChangeEvent.userUpdated,
        AuthChangeEvent.initialSession,
      };
      if (!tracked.contains(state.event) || state.session == null) return;
      unawaited(rememberCurrentAccount());
    });
  }

  /// Guarda (o refresca) la sesión activa en el selector de cuentas. Silencioso
  /// a propósito: es un efecto secundario de un login que ya salió bien, así
  /// que un fallo aquí no debe romper la navegación posterior — como mucho, la
  /// cuenta no queda disponible para alternar.
  Future<void> rememberCurrentAccount() async {
    final session = _client.auth.currentSession;
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null || refreshToken.isEmpty) return;

    final userId = session.user.id;
    UserModel? profile;
    try {
      profile = await getProfileById(userId);
    } on AuthServiceException {
      // Sin conexión o perfil aún no creado por el trigger: se guarda igual con
      // los datos del propio token, que es lo mínimo para reconocer la cuenta.
    }

    final previous = await _accounts.getAccount(userId);
    await _accounts.upsert(
      SavedAccount(
        userId: userId,
        email: profile?.email ?? session.user.email ?? '',
        fullName: profile?.fullName ?? previous?.fullName ?? '',
        role: profile?.role ?? previous?.role ?? UserRole.turista,
        refreshToken: refreshToken,
        savedAt: DateTime.now(),
        // El avatar del perfil manda; `previous` solo cubre el caso de haber
        // guardado sin conexión (profile == null), donde se conserva el que
        // ya se conocía en vez de borrarlo de la lista.
        avatarUrl: profile != null ? profile.avatarUrl : previous?.avatarUrl,
      ),
    );
  }

  /// Alterna a una cuenta guardada sin pedir credenciales: reconstruye su
  /// sesión desde el `refresh_token` persistido.
  ///
  /// Si el token ya no sirve (revocado, caducado o consumido por otro
  /// dispositivo), la entrada se borra y se devuelve un error pidiendo iniciar
  /// sesión de nuevo — dejarla ahí solo repetiría el fallo.
  Future<AuthResult> switchAccount(String userId) async {
    final account = await _accounts.getAccount(userId);
    if (account == null) {
      return const AuthResult.failure(
        'Esa cuenta ya no está guardada en este dispositivo.',
      );
    }
    if (account.userId == currentAuthUser?.id) {
      return const AuthResult.success();
    }

    // La sesión saliente se re-guarda con su token más reciente antes de
    // reemplazarla, para poder volver a ella después.
    await rememberCurrentAccount();

    try {
      await _client.auth.setSession(account.refreshToken);
      // Los servicios singleton cachean en memoria por dueño; sin esto la
      // cuenta nueva heredaría los favoritos de la anterior, porque el
      // pushAndRemoveUntil del selector recrea la UI pero no el proceso.
      FavoritesService().invalidate();
      await rememberCurrentAccount();
      return const AuthResult.success();
    } on AuthException catch (e) {
      await _accounts.remove(userId);
      return AuthResult.failure(
        'No se pudo abrir la sesión de ${account.displayName}: '
        'inicia sesión otra vez. (${_friendlyAuthError(e)})',
      );
    } catch (_) {
      return const AuthResult.failure(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  // ==================== Foto de perfil ====================

  /// Bucket público con las fotos de perfil (ver supabase/sql/015_profile_avatars.sql).
  static const avatarBucket = 'avatars';

  /// Sube [image] a Storage, escribe la URL en `profiles.avatar_url` y la
  /// devuelve.
  ///
  /// Antes de 015 el avatar vivía en `SharedPreferences` bajo una clave global
  /// (no por usuario), así que al alternar de cuenta se veía el avatar del
  /// perfil anterior. Ahora es un dato del perfil como cualquier otro: viaja
  /// con la cuenta y lo ve todo el mundo.
  Future<String> updateAvatar(XFile image) async {
    final user = currentAuthUser;
    if (user == null) {
      throw const AuthServiceException(
        'Necesitas iniciar sesión para cambiar tu foto de perfil.',
      );
    }

    final format = resolveImageUploadFormat(
      image.name,
      reportedMimeType: image.mimeType,
    );
    final objectPath = '${user.id}/${const Uuid().v4()}.${format.extension}';
    final String publicUrl;
    try {
      // readAsBytes y no File: en web `XFile.path` es un `blob:`, no una ruta.
      final bytes = await image.readAsBytes();
      await _client.storage
          .from(avatarBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: format.mimeType,
              upsert: false,
            ),
          );
      publicUrl = _client.storage.from(avatarBucket).getPublicUrl(objectPath);
    } on StorageException catch (e) {
      // La ruta se acaba de generar, así que un 404 solo puede ser el bucket.
      if (e.statusCode == '404') {
        throw const AuthServiceException(
          'Falta crear el almacenamiento de avatares. Corre '
          'supabase/sql/015_profile_avatars.sql en Supabase.',
        );
      }
      throw AuthServiceException('No se pudo subir la foto: ${e.message}');
    } catch (_) {
      throw const AuthServiceException(
        'No se pudo subir la foto. Verifica tu internet e intenta de nuevo.',
      );
    }

    await _writeAvatarUrl(user.id, publicUrl);
    // Refresca la entrada del selector de cuentas para que la nueva foto
    // aparezca ahí sin esperar al próximo login.
    await rememberCurrentAccount();
    return publicUrl;
  }

  /// Vuelve a las iniciales. El archivo en Storage no se borra: sale barato
  /// dejarlo y evita romper una URL que otra pantalla ya tenga cargada.
  Future<void> removeAvatar() async {
    final user = currentAuthUser;
    if (user == null) return;
    await _writeAvatarUrl(user.id, null);
    await rememberCurrentAccount();
  }

  Future<void> _writeAvatarUrl(String userId, String? url) async {
    try {
      await _client
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      // 42501 = permiso denegado sobre la columna: 001 hace `revoke update` y
      // solo 015 vuelve a otorgarlo incluyendo avatar_url.
      if (e.code == '42501') {
        throw const AuthServiceException(
          'Falta el permiso para escribir la foto de perfil. Corre '
          'supabase/sql/015_profile_avatars.sql en Supabase.',
        );
      }
      throw AuthServiceException(
        'No se pudo guardar la foto de perfil: ${e.message}',
      );
    } catch (_) {
      throw const AuthServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
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
    final userId = currentAuthUser?.id;
    try {
      await _client.rpc('delete_own_user');
    } on PostgrestException catch (e) {
      throw AuthServiceException('No se pudo eliminar tu cuenta: ${e.message}');
    } catch (_) {
      throw const AuthServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    if (userId != null) {
      await _accounts.remove(userId);
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
