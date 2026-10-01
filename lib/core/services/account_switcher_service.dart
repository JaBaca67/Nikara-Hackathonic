import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/core/models/saved_account.dart';

/// Almacén local de las sesiones secundarias del "cambio rápido de cuentas".
///
/// Solo persistencia: no habla con Supabase. Quien reconstruye una sesión a
/// partir de un [SavedAccount] es [AuthService.switchAccount] — así este
/// servicio se puede usar en un test sin un cliente de Supabase vivo.
///
/// Se usa `SharedPreferences` y no un almacenamiento cifrado porque es
/// exactamente donde `supabase_flutter` ya guarda la sesión activa (su
/// `LocalStorage` por defecto): meter las secundarias en otro lado daría una
/// falsa sensación de seguridad sin cambiar la superficie real de ataque. Si
/// algún día la sesión activa se mueve a almacenamiento cifrado, esta clase
/// debe moverse con ella.
class AccountSwitcherService {
  factory AccountSwitcherService() => instance;

  AccountSwitcherService._internal();

  static final AccountSwitcherService instance =
      AccountSwitcherService._internal();

  static const _key = 'nikara_saved_accounts_v1';

  /// Máximo de cuentas guardadas; al pasarse se descarta la más antigua. Es un
  /// selector para alternar entre 2-3 perfiles (turista / emprendedor /
  /// fundación), no un gestor de cuentas.
  static const maxAccounts = 5;

  /// Sube en cada escritura para que el selector se refresque sin recargar la
  /// pantalla entera, mismo patrón que `EcoService.revision`.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Ordenadas por [SavedAccount.savedAt] descendente (lo más reciente primero).
  Future<List<SavedAccount>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } on FormatException {
      // Entrada corrupta (escritura interrumpida): se descarta el archivo
      // entero en vez de dejar el selector inutilizable para siempre.
      await prefs.remove(_key);
      return const [];
    }

    final accounts = decoded
        .whereType<Map<String, dynamic>>()
        .map(SavedAccount.fromJson)
        .nonNulls
        .toList();
    accounts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return List.unmodifiable(accounts);
  }

  Future<SavedAccount?> getAccount(String userId) async {
    final accounts = await getAccounts();
    for (final account in accounts) {
      if (account.userId == userId) return account;
    }
    return null;
  }

  /// Inserta o actualiza [account] (la clave es `userId`). Se llama también en
  /// cada `tokenRefreshed`: los refresh tokens de Supabase rotan, así que una
  /// entrada vieja dejaría de servir para volver a esa cuenta.
  Future<void> upsert(SavedAccount account) async {
    final accounts = (await getAccounts()).toList()
      ..removeWhere((a) => a.userId == account.userId)
      ..insert(0, account);
    if (accounts.length > maxAccounts) {
      accounts.removeRange(maxAccounts, accounts.length);
    }
    await _write(accounts);
  }

  Future<void> remove(String userId) async {
    final accounts = (await getAccounts()).toList()
      ..removeWhere((a) => a.userId == userId);
    await _write(accounts);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    revision.value++;
  }

  Future<void> _write(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
    revision.value++;
  }
}
