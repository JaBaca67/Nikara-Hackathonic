import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/models/user_model.dart';

/// What a sign-up/sign-in attempt handed back — a friendly Spanish
/// [message] on failure, ready to drop straight into a SnackBar, instead of
/// callers having to interpret a raw [AuthException].
class AuthResult {
  const AuthResult._({required this.success, this.message});

  const AuthResult.success() : this._(success: true);

  const AuthResult.failure(String message)
    : this._(success: false, message: message);

  final bool success;
  final String? message;
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

  /// Creates the `auth.users` row via Supabase Auth, then a matching
  /// `profiles` row (id/full_name/email/role) — the two-step Supabase
  /// signup pattern, since `profiles` isn't populated automatically without
  /// a database trigger this project doesn't have set up.
  Future<AuthResult> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    UserRole role = UserRole.turista,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const AuthResult.failure(
          'No se pudo crear la cuenta. Intenta de nuevo.',
        );
      }
      await _client.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role.name,
      });
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e));
    } on PostgrestException catch (e) {
      return AuthResult.failure(
        'Tu cuenta se creó, pero no se pudo guardar tu perfil: ${e.message}',
      );
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

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Promotes the signed-in user's `profiles.role` to 'emprendedor' — called
  /// right after they successfully register their first business. Only
  /// touches accounts still on the default 'turista' role, so an 'admin' or
  /// 'auditor' account that registers a business keeps its elevated role
  /// instead of being silently downgraded.
  Future<void> markAsEmprendedor() async {
    final user = currentAuthUser;
    if (user == null) return;
    try {
      final profile = await getProfileById(user.id);
      if (profile == null || profile.role != UserRole.turista) return;
      await _client
          .from('profiles')
          .update({'role': UserRole.emprendedor.name})
          .eq('id', user.id);
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