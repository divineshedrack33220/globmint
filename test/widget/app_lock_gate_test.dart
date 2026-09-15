import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:globe_mint/app/app_lock_gate.dart';
import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/core/widgets/app_button.dart';
import 'package:globe_mint/features/auth/presentation/pages/login_page.dart';
import 'package:globe_mint/features/auth/presentation/widgets/unlock_screen.dart';
import 'package:globe_mint/shared/models/user.dart';
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
  _FakeAuthService({this.user, required MemorySessionStore store})
      : super(
          ApiClient(baseUrl: 'http://x'),
          sessionStore: store,
        );

  User? user;

  @override
  Future<User?> currentSession() async {
    if (user == null) {
      // Mirror the real 401 handling: an invalidated token is cleared from
      // secure storage, which is what makes the app land on /login.
      await clearSession();
    }
    return user;
  }
}

User _user() => User(
      id: 'u1',
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@example.com',
      phone: '1234',
      createdAt: DateTime(2024),
    );

/// Pumps the whole app stack (MaterialApp.router + AppLockGate) with a tiny
/// test router and a real — but fake-backed — AppLockNotifier.
Future<ProviderContainer> _pumpGate(
  WidgetTester tester, {
  required MemorySessionStore store,
  required AppLockService service,
  User? user,
  Duration backgroundThreshold = const Duration(minutes: 5),
}) async {
  final notifier = AppLockNotifier(
    service: service,
    auth: _FakeAuthService(user: user, store: store),
    store: store,
  );
  final container = ProviderContainer(
    overrides: [
      appLockProvider.overrideWith((ref) => notifier),
      sessionStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const Text('WELCOME'),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('HOME'),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final extra = state.extra is Map ? (state.extra as Map) : null;
          return LoginPage(initialEmail: extra?['email'] as String?);
        },
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: router,
        builder: (context, child) => AppLockGate(
          router: router,
          backgroundThreshold: backgroundThreshold,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets(
      'cold start + valid session + biometrics auto-prompts, unlocks, lands on home',
      (tester) async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService(result: true);

    await _pumpGate(tester, store: store, service: service, user: _user());
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 1);
    expect(find.byType(UnlockScreen), findsNothing);
    expect(find.text('WELCOME'), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('cold start without biometrics shows password fallback only',
      (tester) async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService(biometrics: false);

    await _pumpGate(tester, store: store, service: service, user: _user());
    await tester.pumpAndSettle();

    expect(find.byType(UnlockScreen), findsOneWidget);
    // No biometric button when the device has none.
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    // The password fallback is the only action.
    expect(find.widgetWithText(AppButton, 'Use password'), findsOneWidget);
    // Accessible label is present for screen readers.
    expect(find.bySemanticsLabel('Use password'), findsWidgets);
  });

  testWidgets('password fallback routes to /login with the remembered email',
      (tester) async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    await store.writeEmail('ada@example.com');
    final service = _FakeAppLockService(biometrics: false);

    await _pumpGate(tester, store: store, service: service, user: _user());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Use password'));
    await tester.pumpAndSettle();

    expect(find.byType(UnlockScreen), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('invalid stored token is cleared and routed to /login, never '
      'pretending to unlock', (tester) async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService();

    await _pumpGate(tester, store: store, service: service, user: null);
    await tester.pumpAndSettle();

    expect(find.byType(UnlockScreen), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    // The 401 path (currentSession returning null) clears secure storage.
    expect(await store.readToken(), isNull);
  });

  testWidgets('three failed biometric attempts force the password fallback',
      (tester) async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService(biometrics: true, result: false);

    await _pumpGate(tester, store: store, service: service, user: _user());
    await tester.pumpAndSettle();

    // First failure came from the auto-prompt.
    expect(service.authenticateCalls, 1);
    expect(find.widgetWithText(AppButton, 'Unlock with biometrics'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Unlock with biometrics'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Unlock with biometrics'));
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 3);
    expect(find.text('Unlock with biometrics'), findsNothing);
    expect(find.textContaining('Too many failed attempts'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Use password'), findsOneWidget);
  });

  testWidgets('resume after backgrounding beyond threshold re-locks',
      (tester) async {
    final store = MemorySessionStore(); // no token -> starts unlocked
    final service = _FakeAppLockService(biometrics: false);

    await _pumpGate(
      tester,
      store: store,
      service: service,
      backgroundThreshold: Duration.zero,
    );
    await tester.pumpAndSettle();
    expect(find.byType(UnlockScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(UnlockScreen), findsOneWidget);
  });

  testWidgets('short backgrounding below threshold does not re-lock',
      (tester) async {
    final store = MemorySessionStore();
    final service = _FakeAppLockService(biometrics: false);

    await _pumpGate(tester, store: store, service: service);
    await tester.pumpAndSettle();
    expect(find.byType(UnlockScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(UnlockScreen), findsNothing);
  });

  testWidgets('mid-session 401 unlocks the gate and routes to /login',
      (tester) async {
    final store = MemorySessionStore();
    await store.writeToken('tok');
    final service = _FakeAppLockService(result: true);

    final container = await _pumpGate(
      tester,
      store: store,
      service: service,
      user: _user(),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    // Backend rejects the bearer token mid-session.
    container.read(unauthorizedHandlerProvider).notify();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(find.byType(UnlockScreen), findsNothing);
  });
}