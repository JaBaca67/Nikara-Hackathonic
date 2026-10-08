import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';

/// Sincroniza el token FCM de este dispositivo con `device_push_tokens` (ver
/// `supabase/sql/025_push_tokens.sql`). Mismo patrón singleton que el resto
/// de `core/services`; no se suscribe sola — `startTracking()` se llama una
/// sola vez desde `main()`, junto a `AuthService().startTrackingSessions()`,
/// y solo después de `Firebase.initializeApp()`.
///
/// Registro best-effort a propósito: un fallo acá (permiso denegado, sin
/// internet, Firebase todavía sin inicializar) nunca debe impedir el login ni
/// romper las notificaciones in-app, que no dependen de esto.
class PushTokenService {
  factory PushTokenService() => instance;

  PushTokenService._internal();

  static final PushTokenService instance = PushTokenService._internal();

  static const _table = 'device_push_tokens';

  SupabaseClient get _client => Supabase.instance.client;

  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  Future<void> _registration = Future<void>.value();

  /// Eventos en los que el token de este dispositivo se re-registra: cubre
  /// login normal, login OAuth y `AuthService.switchAccount` (los tres
  /// terminan en `signedIn`, ver el comentario de `startTrackingSessions`),
  /// más `initialSession` para el caso de sesión ya activa al abrir la app.
  static const _registerOn = {
    AuthChangeEvent.signedIn,
    AuthChangeEvent.initialSession,
  };

  /// `firebase_messaging` no tiene implementación para Windows/Linux —
  /// llamarlo ahí revienta con `MissingPluginException`. El desktop de
  /// Níkara sigue funcionando igual de bien solo con las notificaciones
  /// in-app, así que acá no hay nada que "arreglar", solo que evitar.
  bool get _platformSupportsPush =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  void startTracking() {
    if (!_platformSupportsPush) return;
    _authSub ??= AuthService().authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        unawaited(_unregisterCurrentDevice());
      } else if (_registerOn.contains(state.event) && state.session != null) {
        unawaited(_registerCurrentDevice());
      }
    });
    // Si FCM rota el token del dispositivo (reinstalación, restauración de
    // backup, etc.), la fila vieja quedaría apuntando a un token muerto.
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(_registerCurrentDevice());
    });
    // Supabase restaura la sesión antes de inicializar Firebase. El evento
    // initialSession puede haber pasado cuando nos suscribimos: registrar
    // también la sesión actual permite recibir push al reabrir la app.
    if (AuthService().currentAuthUser != null) {
      unawaited(_registerCurrentDevice());
    }
  }

  Future<void> _registerCurrentDevice() {
    // initialSession y onTokenRefresh pueden coincidir. Serializar impide
    // que dos registros intenten renovar el mismo token a la vez.
    _registration = _registration.then((_) => _registerCurrentDeviceNow());
    return _registration;
  }

  Future<void> _registerCurrentDeviceNow() async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      if (AuthService().currentAuthUser?.id != userId) return;

      try {
        await _saveToken(userId, token);
      } on PostgrestException catch (e) {
        if (e.code != '42501' || AuthService().currentAuthUser?.id != userId) {
          rethrow;
        }
        // El teléfono puede conservar un token que pertenece a otra cuenta.
        // RLS impide reasignarlo; renovarlo en Firebase invalida el anterior
        // y permite insertar uno propio sin relajar las políticas.
        await FirebaseMessaging.instance.deleteToken();
        final freshToken = await FirebaseMessaging.instance.getToken();
        if (freshToken == null || AuthService().currentAuthUser?.id != userId) {
          return;
        }
        await _saveToken(userId, freshToken);
      }
    } catch (e) {
      debugPrint('[PushTokenService] No se pudo registrar el dispositivo: $e');
    }
  }

  Future<void> _saveToken(String userId, String token) =>
      _client.from(_table).upsert({
        'user_id': userId,
        'token': token,
        'platform': _platformName,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');

  /// Al cerrar sesión de verdad (no un simple cambio de cuenta) el
  /// dispositivo deja de recibir push hasta el próximo login: si no se
  /// borrara, la siguiente persona que use este teléfono vería avisos de la
  /// cuenta anterior.
  Future<void> _unregisterCurrentDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client.from(_table).delete().eq('token', token);
    } catch (e) {
      debugPrint('[PushTokenService] No se pudo retirar el dispositivo: $e');
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }
}
