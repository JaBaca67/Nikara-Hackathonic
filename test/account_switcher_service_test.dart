import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/core/models/saved_account.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/account_switcher_service.dart';

/// Cobertura del almacén del "cambio rápido de cuentas". No toca Supabase a
/// propósito: [AccountSwitcherService] es solo persistencia, y el intercambio
/// real de tokens (`AuthService.switchAccount`) necesita un backend vivo.
///
/// Lo que se protege aquí es lo que rompería el selector en silencio: una
/// entrada duplicada al re-guardar la misma cuenta, un `refresh_token` viejo
/// sobreviviendo a la rotación, o un JSON corrupto dejando la lista
/// inutilizable para siempre.
SavedAccount _account(
  String id, {
  String refreshToken = 'rt-1',
  DateTime? savedAt,
  UserRole role = UserRole.turista,
}) {
  return SavedAccount(
    userId: id,
    email: '$id@nikara.test',
    fullName: 'Cuenta $id',
    role: role,
    refreshToken: refreshToken,
    savedAt: savedAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  const key = 'nikara_saved_accounts_v1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('guarda y recupera una cuenta con todos sus campos', () async {
    final service = AccountSwitcherService();
    await service.upsert(
      _account('a', role: UserRole.emprendedor, refreshToken: 'rt-a'),
    );

    final saved = await service.getAccount('a');
    expect(saved, isNotNull);
    expect(saved!.email, 'a@nikara.test');
    expect(saved.fullName, 'Cuenta a');
    expect(saved.role, UserRole.emprendedor);
    expect(saved.roleLabel, 'Emprendedor');
    expect(saved.refreshToken, 'rt-a');
  });

  test(
    'upsert de la misma cuenta actualiza el token en vez de duplicar',
    () async {
      final service = AccountSwitcherService();
      await service.upsert(_account('a', refreshToken: 'viejo'));
      await service.upsert(_account('a', refreshToken: 'rotado'));

      final accounts = await service.getAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.single.refreshToken, 'rotado');
    },
  );

  test('ordena por savedAt descendente (lo más reciente primero)', () async {
    final service = AccountSwitcherService();
    await service.upsert(_account('vieja', savedAt: DateTime(2026, 1, 1)));
    await service.upsert(_account('nueva', savedAt: DateTime(2026, 6, 1)));

    final accounts = await service.getAccounts();
    expect(accounts.map((a) => a.userId), ['nueva', 'vieja']);
  });

  test('descarta la más antigua al pasar de maxAccounts', () async {
    final service = AccountSwitcherService();
    for (var i = 0; i <= AccountSwitcherService.maxAccounts; i++) {
      await service.upsert(
        _account('cuenta-$i', savedAt: DateTime(2026, 1, 1 + i)),
      );
    }

    final accounts = await service.getAccounts();
    expect(accounts, hasLength(AccountSwitcherService.maxAccounts));
    expect(accounts.map((a) => a.userId), isNot(contains('cuenta-0')));
  });

  test('remove borra solo la cuenta indicada', () async {
    final service = AccountSwitcherService();
    await service.upsert(_account('a'));
    await service.upsert(_account('b'));
    await service.remove('a');

    final accounts = await service.getAccounts();
    expect(accounts.map((a) => a.userId), ['b']);
  });

  test('un JSON corrupto se descarta en vez de romper el selector', () async {
    SharedPreferences.setMockInitialValues({key: 'no-es-json'});

    final service = AccountSwitcherService();
    expect(await service.getAccounts(), isEmpty);

    // Y la lista vuelve a ser usable inmediatamente después.
    await service.upsert(_account('a'));
    expect(await service.getAccounts(), hasLength(1));
  });

  test('una entrada sin refresh_token se ignora al leer', () async {
    SharedPreferences.setMockInitialValues({
      key:
          '[{"user_id":"sin-token","email":"x@y.z"},'
          '{"user_id":"ok","email":"ok@y.z","refresh_token":"rt",'
          '"role":"turista","saved_at":"2026-01-01T00:00:00.000"}]',
    });

    final accounts = await AccountSwitcherService().getAccounts();
    expect(accounts.map((a) => a.userId), ['ok']);
  });

  test('displayName cae al usuario del correo cuando no hay nombre', () {
    final account = SavedAccount(
      userId: 'a',
      email: 'ixchel.galo@nikara.test',
      fullName: '   ',
      role: UserRole.turista,
      refreshToken: 'rt',
      savedAt: DateTime(2026, 1, 1),
    );
    expect(account.displayName, 'ixchel.galo');
    expect(account.initials, 'I');
  });
}
