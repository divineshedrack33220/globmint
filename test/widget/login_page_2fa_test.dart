import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/features/auth/presentation/pages/login_page.dart';
import 'package:globe_mint/shared/models/user.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/auth_service.dart';

/// Fake auth backed by a hand-rolled netless [AuthService] so the widget test
/// exercises the UI's 2FA branch without touching SharedPreferences or HTTP.
class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ApiClient(baseUrl: 'http://x'));

  LoginResult loginResult =
      const LoginResult(requiresTwoFactor: true, challengeToken: 'chal-1');
  int loginCalls = 0;
  int verifyCalls = 0;

  @override
  Future<LoginResult> login(String email, String password) async {
    loginCalls++;
    return loginResult;
  }

  @override
  Future<User> verifyTwoFactor(String challengeToken, String code) async {
    verifyCalls++;
    return User(
      id: 'u1',
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@dev.com',
      phone: '08000000000',
      createdAt: DateTime(2026, 1, 1),
      twoFactorEnabled: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (_, _) => const LoginPage(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('HOME'))),
          ),
        ],
      );

  Future<void> pumpLogin(WidgetTester tester, _FakeAuthService fake) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('2FA login: challenge then verify navigates home',
      (tester) async {
    final fake = _FakeAuthService();
    await pumpLogin(tester, fake);

    await tester.enterText(find.byType(TextField).at(0), 'ada@dev.com');
    await tester.enterText(find.byType(TextField).at(1), 'correct horse');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(fake.loginCalls, 1);
    expect(find.text('Confirm it\'s you'), findsOneWidget);
    expect(find.text('Authenticator code'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Verify & Sign In'));
    await tester.pumpAndSettle();

    expect(fake.verifyCalls, 1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('invalid code length is rejected without calling the service',
      (tester) async {
    final fake = _FakeAuthService();
    await pumpLogin(tester, fake);

    await tester.enterText(find.byType(TextField).at(0), 'ada@dev.com');
    await tester.enterText(find.byType(TextField).at(1), 'correct horse');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Authenticator code'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.tap(find.text('Verify & Sign In'));
    await tester.pumpAndSettle();

    expect(fake.verifyCalls, 0);
    expect(find.text('HOME'), findsNothing);
  });
}