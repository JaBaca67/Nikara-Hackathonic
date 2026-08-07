import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';

void main() {
  setUp(() {
    // AuthService is a singleton — reset it before every test so execution
    // order never leaks state between cases.
    AuthService().resetForTesting();
  });

  group('AuthService seed users', () {
    test('defaults to Sofía as a client with no owned businesses', () {
      final user = AuthService().currentUser;
      expect(user.id, kSofiaUserId);
      expect(user.name, 'Sofía R.');
      expect(user.role, UserRole.client);
      expect(user.ownedBusinessIds, isEmpty);
      expect(user.points, 45);
    });

    test('signInAs(carlos) switches to an owner of 2 businesses', () {
      AuthService().signInAs(kCarlosUserId);
      final user = AuthService().currentUser;
      expect(user.id, kCarlosUserId);
      expect(user.name, 'Carlos M.');
      expect(user.role, UserRole.owner);
      expect(user.ownedBusinessIds, ['biz_1', 'biz_2']);
      expect(user.points, 320);
    });

    test('signInAs falls back to Sofía for an unrecognized id', () {
      AuthService().signInAs('someone_else');
      expect(AuthService().currentUser.id, kSofiaUserId);
    });
  });

  group('AuthService role elevation', () {
    test('elevateToOwner promotes a client and tracks the new business', () {
      final service = AuthService();
      expect(service.currentUser.role, UserRole.client);

      service.elevateToOwner('biz_real_123');

      expect(service.currentUser.role, UserRole.owner);
      expect(service.currentUser.ownedBusinessIds, contains('biz_real_123'));
    });

    test('elevateToOwner is a no-op when the id is already owned', () {
      final service = AuthService();
      service.elevateToOwner('biz_x');
      final afterFirstCall = service.currentUser.ownedBusinessIds;

      service.elevateToOwner('biz_x');

      expect(service.currentUser.ownedBusinessIds, afterFirstCall);
    });

    test('an already-owner user keeps their role when gaining another business', () {
      final service = AuthService();
      service.signInAs(kCarlosUserId);

      service.elevateToOwner('biz_new');

      expect(service.currentUser.role, UserRole.owner);
      expect(service.currentUser.ownedBusinessIds, ['biz_1', 'biz_2', 'biz_new']);
    });

    test('simulatePartnerRegistration elevates using the fixture pool', () {
      final service = AuthService();

      service.simulatePartnerRegistration();
      expect(service.currentUser.role, UserRole.owner);
      expect(service.currentUser.ownedBusinessIds, ['biz_1']);

      service.simulatePartnerRegistration();
      expect(service.currentUser.ownedBusinessIds, ['biz_1', 'biz_2']);
    });
  });

  group('AuthService business removal', () {
    test('removeOwnedBusiness removes a tracked id', () {
      final service = AuthService();
      service.signInAs(kCarlosUserId);

      service.removeOwnedBusiness('biz_1');

      expect(service.currentUser.ownedBusinessIds, ['biz_2']);
    });

    test('removeOwnedBusiness no-ops for an id that is not tracked', () {
      final service = AuthService();
      service.signInAs(kCarlosUserId);

      service.removeOwnedBusiness('not_tracked');

      expect(service.currentUser.ownedBusinessIds, ['biz_1', 'biz_2']);
    });
  });

  test('currentUserNotifier notifies listeners exactly once per change', () {
    final service = AuthService();
    var notifyCount = 0;
    service.currentUserNotifier.addListener(() => notifyCount++);

    service.signInAs(kCarlosUserId);

    expect(notifyCount, 1);
  });
}
