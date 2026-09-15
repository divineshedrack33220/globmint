import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:globe_mint/app/app_lock_gate.dart';
import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/app/router.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/core/widgets/app_button.dart';
import 'package:globe_mint/features/auth/presentation/widgets/unlock_screen.dart';
import 'package:globe_mint/features/home/presentation/pages/home_page.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/app_lock_service.dart';
import 'package:globe_mint/shared/services/session_store.dart';

const _jsonHeaders = {'content-type': 'application/json'};

class _FakeAppLockService extends AppLockService {
  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => true;
}

/// Canned HTTP responses keyed by request path; every other request 404s.
/// Recording [send] calls makes it possible to assert that guarded pages
/// never fire their data requests at boot.
class _StubHttpClient extends http.BaseClient {
  _StubHttpClient({required this.responses});

  final Map<String, http.Response> responses;
  final List<String> calls = [];

  int get transactionsCalls =>
      calls.where((p) => p.endsWith('/transactions')).length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add(request.url.path);
    final res = responses[request.url.path] ??
        http.Response(
          '{"message":"no such route in test harness"}',
          404,
          headers: _jsonHeaders,
        );
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

/// Boots the REAL [appRouter] (with its appLockProvider redirect) under a
/// ProviderScope whose session/api/lock pieces are test doubles. The stock
/// provider wiring (appLockNotifier, authService, apiClient provider) still
/// runs, so this exercises the exact production cold-start path.
Future<_StubHttpClient> _pumpApp(
  WidgetTester tester, {
  required String? token,
  required Map<String, http.Response> responses,
}) async {
  final store = MemorySessionStore(token: token);
  final handler = UnauthorizedHandler();
  final client = _StubHttpClient(responses: responses);
  final api = ApiClient(
    httpClient: client,
    baseUrl: 'http://test',
    sessionStore: store,
  );
  api.onUnauthorized = handler.notify;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        unauthorizedHandlerProvider.overrideWithValue(handler),
        apiClientProvider.overrideWithValue(api),
        appLockServiceProvider.overrideWithValue(_FakeAppLockService()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: appRouter,
        builder: (context, child) =>
            AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return client;
}

void main() {
  testWidgets(
      'cold start with a rejected token never mounts /home, never fires '
      '/transactions, and sends the user to /login', (tester) async {
    final client = await _pumpApp(
      tester,
      token: 'stale',
      responses: {
        '/api/v1/users/me':
            http.Response('{"message":"unauthorized"}', 401, headers: _jsonHeaders),
      },
    );

    // The guarded page must not boot, so its data fetch cannot happen.
    expect(client.transactionsCalls, 0);
    expect(find.byType(HomePage), findsNothing);
    // The 401 left secure storage empty and the gate routed to the login.
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
      'cold start with a valid token on a biometric-less device stays behind '
      'the lock screen and never fires /transactions', (tester) async {
    final client = await _pumpApp(
      tester,
      token: 'valid',
      responses: {
        '/api/v1/users/me': http.Response(
          '{"id":"u1","first_name":"Ada","last_name":"Lovelace",'
          '"email":"ada@example.com","created_at":"2024-01-01T00:00:00Z"}',
          200,
          headers: _jsonHeaders,
        ),
      },
    );

    // Valid session, but no biometrics on web: the gate stays up and the
    // guarded page (and its data calls) is not mounted underneath.
    expect(client.transactionsCalls, 0);
    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Use password'), findsOneWidget);
  });
}