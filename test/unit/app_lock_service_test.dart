import 'package:flutter_test/flutter_test.dart';
import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/shared/models/models.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/app_lock_service.dart';
import 'package:globe_mint/shared/services/auth_service.dart';
import 'package:globe_mint/shared/services/session_store.dart';

class _FakeAppLockService extends AppLockService {
  _FakeAppLockService({this.biometrics = true, this.result = true});

  final bool biometrics;
  bool result;
  int authenticateCalls = 0;

  @override
  Future<bool> isBiometricAvailable() async => biometrics;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    return result;
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.user, this.verifyPinError})
      : super(ApiClient(baseUrl: 'http://x'));

  User? user;
  ApiException? verifyPinError;
  int pinChecks = 0;

  @override
  Future<User?> currentSession() async => user;

  @override
  Future<void> verifyPin(String pin) async {
    pinChecks++;
    if (verifyPinError != null) throw verifyPinError!;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

User _user() => User(
      id: 'u1',
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@example.com',
      phone: '1234',
      createdAt: DateTime(2024),
    );

void main() {
  test('no stored token starts unlocked without prompting', () async {
    final notifier = AppLockNotifier(
      service: _FakeAppLockService(),
      auth: _FakeAuthService(user: _user()),
      store: MemorySessionStore(),
    );
    await _settle();
    expect(notifier.state.status, AppLockStatus.unlocked);
    expect(notifier.state.biometricsAvailable, isFalse);
  });

  test('valid token + biometrics auto-prompts and unlocks', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService(result: true);
    final notifier = AppLockNotifier(
      service: service,
      auth: _FakeAuthService(user: _user()),
      store: store,
    );
    await _settle();
    expect(service.authenticateCalls, 1);
    expect(notifier.state.status, AppLockStatus.unlocked);
  });

  test('declined biometric stays locked and counts failures', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService(result: false);
    final notifier = AppLockNotifier(
      service: service,
      auth: _FakeAuthService(user: _user()),
      store: store,
    );
    await _settle();
    expect(notifier.state.status, AppLockStatus.locked);
    expect(notifier.state.failedAttempts, 1);

    await notifier.unlockWithBiometric();
    expect(notifier.state.status, AppLockStatus.locked);
    expect(notifier.state.failedAttempts, 2);

    await notifier.unlockWithBiometric();
    expect(notifier.state.failedAttempts, 3);
    expect(notifier.state.biometricsAvailable, isFalse);
    expect(notifier.state.passwordFallbackRequired, isTrue);
  });

  test('invalid token (401 clears it) routes to login', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final notifier = AppLockNotifier(
      service: _FakeAppLockService(),
      auth: _FakeAuthService(user: null),
      store: store,
    );
    await _settle();
    expect(notifier.state.status, AppLockStatus.unlocked);
    expect(notifier.state.needsLogin, isTrue);
  });

  test('no biometrics: locked, password fallback is required', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final notifier = AppLockNotifier(
      service: _FakeAppLockService(biometrics: false),
      auth: _FakeAuthService(user: _user()),
      store: store,
    );
    await _settle();
    expect(notifier.state.status, AppLockStatus.locked);
    expect(notifier.state.passwordFallbackRequired, isTrue);

    notifier.signalPasswordFallback();
    expect(notifier.state.status, AppLockStatus.unlocked);
    expect(notifier.state.needsLogin, isTrue);
  });

  test('expireToLogin opens the gate for /login', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService();
    final notifier = AppLockNotifier(
      service: service,
      auth: _FakeAuthService(user: _user()),
      store: store,
    );
    await notifier.unlockWithBiometric();
    expect(notifier.state.status, AppLockStatus.unlocked);

    await notifier.expireToLogin();
    expect(notifier.state.status, AppLockStatus.unlocked);
    expect(notifier.state.needsLogin, isTrue);
  });

  test('relock re-covers the app and re-enables prompting', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService(result: true);
    final notifier = AppLockNotifier(
      service: service,
      auth: _FakeAuthService(user: _user()),
      store: store,
    );
    await notifier.unlockWithBiometric();
    expect(notifier.state.status, AppLockStatus.unlocked);

    notifier.relock();
    expect(notifier.state.status, AppLockStatus.locked);

    await _settle();
    // Auto-prompt re-arms after a relock.
    expect(service.authenticateCalls, greaterThanOrEqualTo(2));
    expect(notifier.state.status, AppLockStatus.unlocked);
  });

  test('correct PIN unlocks straight through without needing a login',
      () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final auth = _FakeAuthService(user: _user());
    final notifier = AppLockNotifier(
      service: _FakeAppLockService(biometrics: false),
      auth: auth,
      store: store,
    );
    await _settle();
    expect(notifier.state.status, AppLockStatus.locked);

    await notifier.unlockWithPin('123456');

    expect(auth.pinChecks, 1);
    expect(notifier.state.status, AppLockStatus.unlocked);
    expect(notifier.state.needsLogin, isFalse);
    expect(notifier.state.sessionExists, isTrue);
    expect(notifier.state.failedAttempts, 0);
  });

  test('wrong PIN stays locked, counts failures, and after 3 forces password',
      () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final auth = _FakeAuthService(
      user: _user(),
      verifyPinError: ApiException(
        400,
        'Invalid PIN. Please try again.',
        code: 'INVALID_PIN',
      ),
    );
    final notifier = AppLockNotifier(
      service: _FakeAppLockService(biometrics: false),
      auth: auth,
      store: store,
    );
    await _settle();

    await notifier.unlockWithPin('000000');
    expect(notifier.state.status, AppLockStatus.locked);
    expect(notifier.state.pinFailures, 1);
    expect(notifier.state.pinError, 'Invalid PIN. Please try again.');
    expect(notifier.state.pinFallbackRequired, isFalse);

    await notifier.unlockWithPin('000000');
    expect(notifier.state.pinFailures, 2);

    await notifier.unlockWithPin('000000');
    expect(notifier.state.pinFailures, 3);
    expect(notifier.state.pinFallbackRequired, isTrue);
    expect(
      notifier.state.pinError,
      'Too many failed attempts — use your password instead.',
    );

    // Locked out: further attempts are ignored without hitting the backend.
    final calls = auth.pinChecks;
    await notifier.unlockWithPin('123456');
    expect(auth.pinChecks, calls);
  });

  test('signalPinFallback shows the pad; cancelPinFallback returns to '
      'biometrics', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final notifier = AppLockNotifier(
      service: _FakeAppLockService(biometrics: true),
      auth: _FakeAuthService(user: _user()),
      store: store,
    );
    await _settle();
    expect(notifier.state.pinMode, isFalse);

    notifier.signalPinFallback();
    expect(notifier.state.pinMode, isTrue);

    notifier.cancelPinFallback();
    expect(notifier.state.pinMode, isFalse);
  });

  test('a server/network failure shows an error but never counts as a wrong '
      'PIN', () async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final auth = _FakeAuthService(
      user: _user(),
      verifyPinError: ApiException(500, 'Something went wrong'),
    );
    final notifier = AppLockNotifier(
      service: _FakeAppLockService(biometrics: false),
      auth: auth,
      store: store,
    );
    await _settle();

    await notifier.unlockWithPin('123456');

    expect(notifier.state.status, AppLockStatus.locked);
    expect(notifier.state.pinFailures, 0);
    expect(
      notifier.state.pinError,
      'Could not verify your PIN. Please try again.',
    );
  });
}