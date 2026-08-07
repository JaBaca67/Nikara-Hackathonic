import 'package:flutter/foundation.dart';

import 'package:nikara_app/core/models/user_model.dart';

/// Stable ids for the two Dev Mode seed users — [DevRoleSwitcherSheet] and
/// tests address them by id instead of re-constructing [UserModel]s.
const kSofiaUserId = 'user_sofia';
const kCarlosUserId = 'user_carlos';

/// Local, in-memory, multi-role auth for "Dev Mode" — lets a developer/QA
/// preview the client vs. business-owner experience instantly, without
/// registering a real business or juggling multiple real device accounts.
///
/// This is intentionally separate from `UserSessionService` (the real,
/// single, SharedPreferences-persisted device account that Login/Register/
/// avatar-upload actually drive): nothing here is persisted, so it resets
/// to Sofía every app restart. A singleton — every call to `AuthService()`
/// returns the same instance, so [currentUserNotifier] is shared globally.
class AuthService {
  factory AuthService() => instance;

  AuthService._internal() : currentUserNotifier = ValueNotifier(_seedSofia());

  static final AuthService instance = AuthService._internal();

  /// Reactive current Dev Mode identity — screens listen via
  /// `addListener`/`ValueListenableBuilder` to update instantly when the
  /// role switcher (or the wizard's owner-elevation flow) changes it.
  final ValueNotifier<UserModel> currentUserNotifier;

  UserModel get currentUser => currentUserNotifier.value;

  static UserModel _seedSofia() => const UserModel(
    id: kSofiaUserId,
    name: 'Sofía R.',
    email: 'sofia.exploradora@nikara.test',
    avatarUrl: '',
    role: UserRole.client,
    ownedBusinessIds: [],
    favoriteBusinessIds: [],
    points: 45,
  );

  static UserModel _seedCarlos() => const UserModel(
    id: kCarlosUserId,
    name: 'Carlos M.',
    email: 'carlos.anfitrion@nikara.test',
    avatarUrl: '',
    role: UserRole.owner,
    ownedBusinessIds: ['biz_1', 'biz_2'],
    favoriteBusinessIds: [],
    points: 320,
  );

  /// Switches the active Dev Mode identity to one of the two seed users —
  /// anything other than [kCarlosUserId] falls back to Sofía.
  void signInAs(String userId) {
    currentUserNotifier.value = userId == kCarlosUserId
        ? _seedCarlos()
        : _seedSofia();
  }

  /// The role-elevation moment (PedidosYa Partner-style): a `client` who
  /// finishes registering a real business through the wizard becomes an
  /// `owner` of it immediately — reactive, no restart, no re-login. A
  /// no-op if [businessId] is already in the current user's list.
  void elevateToOwner(String businessId) {
    final current = currentUserNotifier.value;
    if (current.ownedBusinessIds.contains(businessId)) return;
    currentUserNotifier.value = current.copyWith(
      role: UserRole.owner,
      ownedBusinessIds: [...current.ownedBusinessIds, businessId],
    );
  }

  /// "➕ Simular paso por Registro Web / Partner" — the same elevation as
  /// [elevateToOwner], against a pooled dev-fixture business id instead of
  /// one created for real through the wizard, for a one-tap preview of the
  /// client-to-owner transition.
  void simulatePartnerRegistration() {
    const pool = ['biz_1', 'biz_2', 'biz_3'];
    final current = currentUserNotifier.value;
    final nextId = pool.firstWhere(
      (id) => !current.ownedBusinessIds.contains(id),
      orElse: () => pool.last,
    );
    elevateToOwner(nextId);
  }

  /// Removes [businessId] from the current user's owned list — a no-op if
  /// it isn't tracked there (e.g. it belongs to the real device account
  /// instead of the active Dev Mode persona).
  void removeOwnedBusiness(String businessId) {
    final current = currentUserNotifier.value;
    if (!current.ownedBusinessIds.contains(businessId)) return;
    currentUserNotifier.value = current.copyWith(
      ownedBusinessIds: current.ownedBusinessIds
          .where((id) => id != businessId)
          .toList(),
    );
  }

  /// Test-only: resets Dev Mode back to its default seed state (Sofía) so
  /// each test starts from a known baseline regardless of execution order
  /// — the singleton would otherwise leak state between test cases.
  @visibleForTesting
  void resetForTesting() {
    currentUserNotifier.value = _seedSofia();
  }
}
