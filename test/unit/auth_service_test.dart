import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/auth_service.dart';
import 'package:globe_mint/shared/services/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorySessionStore store;

  Future<String?> storedToken() => store.readToken();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = MemorySessionStore();
  });

  AuthService buildAuth(MockClient mock) {
    final api = ApiClient(
      httpClient: mock,
      baseUrl: 'http://x',
      sessionStore: store,
    );
    return AuthService(api, sessionStore: store);
  }

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
    final auth = buildAuth(mock);

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
    final auth = buildAuth(mock);

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
    final auth = buildAuth(mock);

    final user = await auth.verifyTwoFactor('challenge-1', '123456');

    expect(user.id, 'u2');
    expect(await storedToken(), 'tok-2fa');
    expect(auth.isAuthenticated, isTrue);
  });

  test('logout clears the stored token; next launch treats the user as out',
      () async {
    final mock = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/logout') {
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }
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
    final auth = buildAuth(mock);
    await auth.login('ada@dev.com', 'password');
    expect(await storedToken(), 'tok-123');

    await auth.logout();

    expect(await storedToken(), isNull);
    expect(auth.isAuthenticated, isFalse);
  });

  test('currentSession restores a valid stored session via /users/me',
      () async {
    store = MemorySessionStore(
      token: 'tok-123',
      email: 'ada@dev.com',
    );
    final mock = MockClient((request) async {
      expect(request.url.path, '/api/v1/users/me');
      expect(request.headers['Authorization'], 'Bearer tok-123');
      return http.Response(
        jsonEncode({
          'id': 'u1',
          'first_name': 'Ada',
          'last_name': 'Lovelace',
          'email': 'ada@dev.com',
          'phone': '08000000000',
          'created_at': '2026-01-01T00:00:00Z',
          'status': 'verified',
          'two_factor_enabled': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = buildAuth(mock);

    final user = await auth.currentSession();

    expect(user?.email, 'ada@dev.com');
    expect(auth.isAuthenticated, isTrue);
    expect(await storedToken(), 'tok-123');
  });

  test('currentSession clears the token when the backend rejects it (401)',
      () async {
    store = MemorySessionStore(token: 'expired-token');
    final mock = MockClient((request) async {
      expect(request.url.path, '/api/v1/users/me');
      return http.Response(
        jsonEncode({'message': 'Invalid session', 'code': 'INVALID_SESSION'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = buildAuth(mock);

    final user = await auth.currentSession();

    expect(user, isNull);
    expect(auth.isAuthenticated, isFalse);
    expect(await storedToken(), isNull);
  });

  test('changePassword deletes the stored token afterwards', () async {
    store = MemorySessionStore(token: 'tok-123');
    final mock = MockClient((request) async {
      expect(request.url.path, '/api/v1/auth/password');
      return http.Response(
        jsonEncode({'message': 'updated'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = buildAuth(mock);

    await auth.changePassword(
      currentPassword: 'old-pass',
      newPassword: 'new-pass-word',
    );

    expect(await storedToken(), isNull);
    expect(auth.isAuthenticated, isFalse);
  });

  test('a stale 401 for a replaced session never signs out the fresh token',
      () async {
    store = MemorySessionStore(token: 'stale-token');
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'token': 'fresh-token',
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
    final auth = buildAuth(mock);

    await auth.login('ada@dev.com', 'password');
    expect(await storedToken(), 'fresh-token');

    // A request that had carried the OLD token comes back 401 after the
    // re-login already stored the fresh one.
    await auth.handleSessionExpired(rejectedToken: 'stale-token');

    expect(await storedToken(), 'fresh-token');
    expect(auth.isAuthenticated, isTrue);
  });

  test('handleSessionExpired clears exactly the token that was rejected',
      () async {
    store = MemorySessionStore(token: 'current-token');
    final mock = MockClient((request) async {
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    });
    final auth = buildAuth(mock);

    await auth.handleSessionExpired(rejectedToken: 'current-token');

    expect(await storedToken(), isNull);
    expect(auth.isAuthenticated, isFalse);
  });
}