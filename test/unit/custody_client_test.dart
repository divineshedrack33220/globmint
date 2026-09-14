import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/savings_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('CustodyStatus.fromJson parses an unclaimed clone', () {
    final status = CustodyStatus.fromJson({
      'clone': '0x0925F132e9d44D70e6A106f173d8842c81765c51',
      'owner': '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      'placeholder': '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      'claimed': false,
      'nonce': 3,
    });

    expect(status.claimed, isFalse);
    expect(status.ownerShort, '0xf39F…2266');
    expect(status.nonce, 3);
    expect(status.cloneShort, isNotEmpty);
  });

  test('CustodyStatus.fromJson tolerates a missing placeholder', () {
    final status = CustodyStatus.fromJson({
      'clone': '0x0925F132e9d44D70e6A106f173d8842c81765c51',
      'owner': '0x1111111111111111111111111111111111111111',
      'claimed': true,
      'nonce': 0,
    });

    expect(status.claimed, isTrue);
    expect(status.placeholder, isEmpty);
    expect(status.nonce, 0);
  });

  test('getCustodyStatus requests GET /savings/custody', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'clone': '0xA',
            'owner': '0xB',
            'placeholder': '0xC',
            'claimed': false,
            'nonce': 7,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final savings = SavingsClient(client);

    final status = await savings.getCustodyStatus();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/savings/custody');
    expect(status.owner, '0xB');
    expect(status.placeholder, '0xC');
    expect(status.claimed, isFalse);
    expect(status.nonce, 7);
  });
}