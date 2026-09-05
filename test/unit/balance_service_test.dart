import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/balance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  BalanceService serviceWith({
    required Map<String, dynamic> balances,
    Map<String, dynamic>? vaultStatus,
  }) {
    final mock = MockClient((request) async {
      final path = request.url.path;
      final Object body;
      if (path == '/api/v1/balances') {
        body = {'balances': balances['balances']};
      } else if (path == '/api/v1/savings/vault-status') {
        body = vaultStatus!;
      } else {
        return http.Response('not found', 404);
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });
    return BalanceService(ApiClient(httpClient: mock, baseUrl: 'http://x'));
  }

  test('maps balances and the on-chain vault into an account summary', () async {
    final svc = serviceWith(
      balances: {
        'balances': [
          {
            'account_id': 'acc-ngn',
            'currency': 'NGN',
            'amount': '25000.00',
            'amount_minor': 2500000,
            'kind': 'available',
          },
          {
            'account_id': 'acc-usdt',
            'currency': 'USDT',
            'amount': '0',
            'amount_minor': 0,
            'kind': 'savings',
          },
        ],
      },
      vaultStatus: {'vault_usdc_balance': '8.500000 USDC'},
    );

    final summary = await svc.getAccountSummary();

    expect(summary.available.currency, 'NGN');
    expect(summary.available.balance, 25000.0);
    expect(summary.savings.currency, 'USDT');
    expect(summary.savings.balance, 8.5);
    expect(summary.totalNgnEquivalent, 25000.0);
    expect(summary.totalUsdtEquivalent, 8.5);
  });

  test('falls back to zero vault when vault-status is missing', () async {
    final svc = serviceWith(
      balances: {
        'balances': [
          {
            'account_id': 'acc-ngn',
            'currency': 'NGN',
            'amount': '10.00',
            'amount_minor': 1000,
            'kind': 'available',
          },
        ],
      },
      vaultStatus: {},
    );

    final summary = await svc.getAccountSummary();

    expect(summary.savings.balance, 0);
    expect(summary.totalNgnEquivalent, 10.0);
  });

  test('tolerates a failing vault-status call', () async {
    final svc = serviceWith(
      balances: {
        'balances': [
          {
            'account_id': 'acc-ngn',
            'currency': 'NGN',
            'amount': '5.00',
            'amount_minor': 500,
            'kind': 'available',
          },
        ],
      },
      vaultStatus: {'error': 'boom'},
    );

    final summary = await svc.getAccountSummary();

    expect(summary.savings.balance, 0);
    expect(summary.available.balance, 5.0);
  });
}