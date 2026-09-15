import 'package:flutter_test/flutter_test.dart';
import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/app/router.dart';

void main() {
  const startingLock = AppLockState();
  const lockedLock =
      AppLockState(status: AppLockStatus.locked, sessionExists: true);
  const unlockedLock = AppLockState(
    status: AppLockStatus.unlocked,
    sessionExists: true,
  );
  const needsLoginLock = AppLockState(
    status: AppLockStatus.unlocked,
    needsLogin: true,
  );
  const noSessionLock = AppLockState(status: AppLockStatus.unlocked);

  group('appLockRedirect', () {
    test('public routes are never redirected', () {
      for (final path in [
        '/welcome',
        '/login',
        '/forgot-password',
        '/create-account',
        '/create-pin',
        '/verify',
        '/legal/privacy',
        '/legal/faq',
      ]) {
        expect(
          appLockRedirect(lock: startingLock, isAuthenticated: false, path: path),
          isNull,
          reason: '$path must always render',
        );
      }
    });

    test('guarded routes never mount while the session is still validating', () {
      for (final path in ['/home', '/savings', '/savings/withdraw', '/pay/send-beneficiary', '/activity', '/activity/1', '/profile']) {
        expect(
          appLockRedirect(lock: startingLock, isAuthenticated: false, path: path),
          '/welcome',
          reason: '$path must not boot during validation',
        );
      }
    });

    test('guarded routes are hidden behind /welcome while locked', () {
      expect(
        appLockRedirect(lock: lockedLock, isAuthenticated: true, path: '/home'),
        '/welcome',
      );
      expect(
        appLockRedirect(lock: lockedLock, isAuthenticated: false, path: '/home'),
        '/welcome',
      );
    });

    test('a session that must be re-established routes to /login', () {
      expect(
        appLockRedirect(lock: needsLoginLock, isAuthenticated: false, path: '/home'),
        '/login',
      );
    });

    test('an unlocked-but-unauthenticated guard bounces to /login', () {
      expect(
        appLockRedirect(lock: noSessionLock, isAuthenticated: false, path: '/home'),
        '/login',
      );
      expect(
        appLockRedirect(lock: noSessionLock, isAuthenticated: true, path: '/home'),
        isNull,
        reason: 'a fresh in-app login lets the user reach /home',
      );
    });

    test('an unlocked session allows the guarded routes', () {
      for (final path in ['/home', '/savings', '/pay', '/activity', '/profile']) {
        expect(
          appLockRedirect(lock: unlockedLock, isAuthenticated: true, path: path),
          isNull,
          reason: '$path must render after unlock',
        );
      }
    });
  });
}