import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:globe_mint/core/constants/app_constants.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String?> storedToken() async =>
      (await SharedPreferences.getInstance()).getString(AppConstants.authTokenKey);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login surfaces the 2FA challenge without storing a token', () async {
    final mock = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/auth/login');
      return http.Response(
        jsonEncode({
          'requires_2fa': true,
          'challenge_token': 'challenge-1',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = AuthService(ApiClient(httpClient: mock, baseUrl: 'http://x'));

    final result = await auth.login('a@b.com', 'password');

    expect(result.requiresTwoFactor, isTrue);
    expect(result.challengeToken, 'challenge-1');
    expect(result.user, isNull);
    expect(await storedToken(), isNull);
  });

  test('password login stores the token and user', () async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'token': 'tok-123',
          'requires_2fa': false,
          'user': {
            'id': 'u1',
            'first_name': 'Ada',
            'last_name': 'Lovelace',
            'email': 'ada@dev.com',
            'phone': '08000000000',
            'created_at': '2026-01-01T00:00:00Z',
            'status': 'verified',
            'two_factor_enabled': false,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = AuthService(ApiClient(httpClient: mock, baseUrl: 'http://x'));

    final result = await auth.login('ada@dev.com', 'password');

    expect(result.requiresTwoFactor, isFalse);
    expect(result.user?.firstName, 'Ada');
    expect(auth.isAuthenticated, isTrue);
    expect(await storedToken(), 'tok-123');
  });

  test('verifyTwoFactor completes the session and stores the token', () async {
    final mock = MockClient((request) async {
      expect(request.url.path, '/api/v1/auth/2fa/verify');
      return http.Response(
        jsonEncode({
          'token': 'tok-2fa',
          'user': {
            'id': 'u2',
            'first_name': 'Grace',
            'last_name': 'Hopper',
            'email': 'grace@navy.dev',
            'phone': '08000000001',
            'created_at': '2026-02-02T00:00:00Z',
            'status': 'verified',
            'two_factor_enabled': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = AuthService(ApiClient(httpClient: mock, baseUrl: 'http://x'));

    final user = await auth.verifyTwoFactor('challenge-1', '123456');

    expect(user.id, 'u2');
    expect(await storedToken(), 'tok-2fa');
    expect(auth.isAuthenticated, isTrue);
  });
}