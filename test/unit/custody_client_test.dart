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

  test('CustodyQuote.fromJson parses a transfer-ownership quote', () {
    final quote = CustodyQuote.fromJson({
      'domain': {
        'name': 'GlobmintVault',
        'version': '1',
        'chain_id': 1337,
        'verifying_contract': '0x0925F132e9d44D70e6A106f173d8842c81765c51',
      },
      'primary_type': 'TransferOwnership',
      'message': {
        'new_owner': '0x4444444444444444444444444444444444444444',
        'nonce': 3,
        'deadline': 1710000000,
      },
      'clone_owner': '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    });

    expect(quote.primaryType, 'TransferOwnership');
    expect(quote.message.newOwner, '0x4444444444444444444444444444444444444444');
    expect(quote.message.nonce, 3);
    expect(quote.message.deadline, 1710000000);
    expect(quote.cloneOwner, '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
    expect(quote.domain.verifyingContract, '0x0925F132e9d44D70e6A106f173d8842c81765c51');
  });

  test('prepareCustody requests GET /savings/custody/prepare?new_owner=…',
      () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'domain': {
              'name': 'GlobmintVault',
              'version': '1',
              'chain_id': 1337,
              'verifying_contract': '0xClone',
            },
            'primary_type': 'TransferOwnership',
            'message': {
              'new_owner': '0x4444444444444444444444444444444444444444',
              'nonce': 0,
              'deadline': 1710000000,
            },
            'clone_owner': '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final savings = SavingsClient(client);

    final quote = await savings.prepareCustody(
      '0x4444444444444444444444444444444444444444',
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/savings/custody/prepare');
    expect(captured.url.queryParameters['new_owner'],
        '0x4444444444444444444444444444444444444444');
    expect(quote.message.newOwner, '0x4444444444444444444444444444444444444444');
    expect(quote.message.nonce, 0);
  });

  test('claimCustody POSTs /savings/custody/claim with an idempotency key',
      () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'claimed': true,
            'new_owner': '0x4444444444444444444444444444444444444444',
            'tx_hash': '0xTXN',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final savings = SavingsClient(client);

    final result = await savings.claimCustody(
      '0x4444444444444444444444444444444444444444',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/savings/custody/claim');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['new_owner'], '0x4444444444444444444444444444444444444444');
    expect(captured.headers.containsKey('Idempotency-Key'), isTrue);
    expect(result.claimed, isTrue);
    expect(result.txHash, '0xTXN');
  });
}