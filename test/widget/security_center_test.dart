import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/session_store.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/features/profile/presentation/pages/security_center_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('security center renders active devices and security activity',
      (tester) async {
    final putBodies = <String>[];
    final client = MockClient((request) async {
      final host = request.url.host;
      final path = request.url.path.split('?').first;
      if (host == 'x') {
        switch (path) {
          case '/api/v1/devices':
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'dev-1',
                    'name': 'Pixel 9',
                    'detail': 'Android — Kano',
                    'ip': '105.112.22.30',
                    'is_current': true,
                    'last_active_at': '2026-09-17T20:00:00Z',
                    'created_at': '2026-09-01T09:00:00Z',
                  },
                ],
                'total': 1,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          case '/api/v1/security-events':
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'ev-1',
                    'type': 'failed_login',
                    'title': 'Failed login blocked',
                    'detail': 'Wrong password × 3 from Lagos, NG',
                    'severity': 'warning',
                    'ip': '197.210.10.20',
                    'user_agent': 'Chrome/126',
                    'device': 'macOS',
                    'created_at': '2026-09-17T19:40:00Z',
                  },
                  {
                    'id': 'ev-2',
                    'type': 'new_signin',
                    'title': 'New sign-in',
                    'detail': 'Signed in from Safari on iPhone',
                    'severity': 'info',
                    'ip': '105.112.22.40',
                    'user_agent': 'Safari/18',
                    'device': 'iPhone',
                    'created_at': '2026-09-17T18:10:00Z',
                  },
                ],
                'total': 2,
                'limit': 20,
                'offset': 0,
                'has_more': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          case '/api/v1/security/prefs':
            if (request.method == 'PUT') {
              putBodies.add(request.body);
              return http.Response('{}', 200,
                  headers: {'content-type': 'application/json'});
            }
            return http.Response('{}', 200,
                headers: {'content-type': 'application/json'});
          default:
            return http.Response('Not found', 404,
                headers: {'content-type': 'application/json'});
        }
      }
      return http.Response('Not found', 404,
          headers: {'content-type': 'application/json'});
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(ApiClient(
          baseUrl: 'http://x',
          httpClient: client,
          sessionStore: MemorySessionStore(),
        )),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.dark(),
            home: const SecurityCenterPage(),
          ),
      ),
    );

    // Devices + activity load asynchronously.
    await tester.pumpAndSettle();

    expect(find.text('Active Devices'), findsOneWidget);
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.text('Recent Security Activity'), findsOneWidget);
    expect(find.text('Failed login blocked'), findsOneWidget);
    expect(find.text('New sign-in'), findsOneWidget);
  });
}
