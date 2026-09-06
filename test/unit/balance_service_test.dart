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
  BalanceService serviceWithRate(
      {required List<Map<String, dynamic>> balances, int? rateMinor}) {
    final mock = MockClient((request) async {
      if (request.url.path == '/api/v1/balances') {
        return http.Response(jsonEncode({'balances': balances}), 200,
            headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/v1/money/rate' && rateMinor != null) {
        return http.Response(jsonEncode({'rate_minor': rateMinor}), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('not found', 404);
    });
    return BalanceService(ApiClient(httpClient: mock, baseUrl: 'http://x'));
  }

  BalanceService serviceWith({required List<Map<String, dynamic>> balances}) {
    return serviceWithRate(balances: balances, rateMinor: null);
  }

  test('maps personal ledger rows into available + savings totals', () async {
    final svc = serviceWith(balances: [
      {
        'account_id': 'acc-ngn',
        'currency': 'NGN',
        'amount': '25000.00',
        'amount_minor': 2500000,
        'kind': 'available',
      },
      {
        'account_id': 'acc-sav',
        'currency': 'NGN',
        'amount': '5000.00',
        'amount_minor': 500000,
        'kind': 'savings',
      },
    ]);

    final summary = await svc.getAccountSummary();

    expect(summary.available.currency, 'NGN');
    expect(summary.available.balance, 25000.0);
    expect(summary.savings.balance, 5000.0);
    expect(summary.totalNgnEquivalent, 30000.0);
    expect(summary.totalUsdtEquivalent, closeTo(30000.0 / 1604.5, 1e-9));
  });

  test('empty account summarizes to zero with no vault dependence', () async {
    // The vault-status endpoint is unreachable here (404): personal totals
    // must not depend on any on-chain figure.
    final svc = serviceWith(balances: [
      {
        'account_id': 'acc-ngn',
        'currency': 'NGN',
        'amount': '0.00',
        'amount_minor': 0,
        'kind': 'available',
      },
      {
        'account_id': 'acc-sav',
        'currency': 'NGN',
        'amount': '0.00',
        'amount_minor': 0,
        'kind': 'savings',
      },
    ]);

    final summary = await svc.getAccountSummary();

    expect(summary.available.balance, 0);
    expect(summary.savings.balance, 0);
    expect(summary.totalNgnEquivalent, 0);
    expect(summary.totalUsdtEquivalent, 0);
  });

  test('falls back to minor units when the major amount is missing', () async {
    final svc = serviceWith(balances: [
      {
        'account_id': 'acc-ngn',
        'currency': 'NGN',
        'amount_minor': 500,
        'kind': 'available',
      },
    ]);

    final summary = await svc.getAccountSummary();

    expect(summary.available.balance, 5.0);
    expect(summary.savings.balance, 0);
    expect(summary.totalNgnEquivalent, 5.0);
  });

  test('uses the live server rate when the feed-backed endpoint answers',
      () async {
    final svc = serviceWithRate(balances: [
      {
        'account_id': 'acc-ngn',
        'currency': 'NGN',
        'amount': '1000.00',
        'amount_minor': 100000,
        'kind': 'available',
      },
    ], rateMinor: 170000);

    final summary = await svc.getAccountSummary();

    expect(summary.currentRate, 1700.0);
    expect(summary.totalNgnEquivalent, 1000.0);
    expect(summary.totalUsdtEquivalent, closeTo(1000.0 / 1700.0, 1e-9));
  });
}
