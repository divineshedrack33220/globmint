import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/features/savings/presentation/widgets/custody_claim_sheet.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/savings_client.dart';
import 'package:globe_mint/shared/services/session_store.dart';
import 'package:globe_mint/shared/services/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWalletBackend implements WalletBackend {
  @override
  String get name => 'Fake';

  @override
  bool isAvailable() => true;

  @override
  Future<List<String>> requestAccounts() async => const ['0xAAAA'];

  @override
  Future<List<String>> accounts() async => const ['0xAAAA'];

  @override
  Future<int> chainId() async => 1337;

  @override
  Future<void> switchChain(int chainId) async {}

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) async =>
      '0xSig';
}

CustodyStatus _unclaimed() => const CustodyStatus(
      clone: '0x0925F132e9d44D70e6A106f173d8842c81765c51',
      owner: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      placeholder: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      claimed: false,
      nonce: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late List<String> called;

  MockClient client({
    int claimStatus = 200,
    Map<String, dynamic>? claimBody,
  }) {
    return MockClient((request) async {
      called.add('${request.method} ${request.url.path}');
      final path = request.url.path;
      if (path.endsWith('/savings/deposit-info')) {
        return http.Response(
          jsonEncode({
            'address': '0xDeposit',
            'vault_contract': '0xVault',
            'stablecoin_symbol': 'USDC',
            'stablecoin_contract': '0xUsdc',
            'network': 'hardhat',
            'chain_id': 1337,
            'mode': 'vault',
            'require_user_signature': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/savings/custody/prepare')) {
        return http.Response(
          jsonEncode({
            'domain': {
              'name': 'GlobmintVault',
              'version': '1',
              'chain_id': 1337,
              'verifying_contract': '0x0925F132e9d44D70e6A106f173d8842c81765c51',
            },
            'primary_type': 'TransferOwnership',
            'message': {
              'new_owner': '0xAAAA',
              'nonce': 0,
              'deadline': 1710000000,
            },
            'clone_owner': '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/savings/custody/claim')) {
        return http.Response(
          jsonEncode(claimBody ?? {
            'claimed': true,
            'new_owner': '0xAAAA',
            'tx_hash': '0xTXN123',
          }),
          claimStatus,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404,
          headers: {'content-type': 'application/json'});
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    called = [];
    container = ProviderContainer(
      overrides: [
        walletServiceProvider.overrideWithValue(
          WalletService(backends: [_FakeWalletBackend()]),
        ),
        apiClientProvider.overrideWithValue(ApiClient(
          baseUrl: 'http://x',
          httpClient: client(),
          sessionStore: MemorySessionStore(),
        )),
      ],
    );
    addTearDown(container.dispose);
  });

  testWidgets('unclaimed sheet requires a wallet and then relays the claim',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => CustodyClaimSheet.show(context, _unclaimed()),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('platform placeholder'), findsWidgets);
    expect(find.text('Claim custody'), findsOneWidget);

    // Not connected yet: the claim must stay disabled.
    expect(find.text('Claim custody with my wallet'), findsNothing);

    await tester.tap(find.text('Connect wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Claim custody with my wallet'), findsOneWidget);
    expect(find.textContaining('Custody will be handed to your wallet'),
        findsOneWidget);

    await tester.ensureVisible(find.text('Claim custody with my wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claim custody with my wallet'));
    await tester.pumpAndSettle();

    expect(called, contains('GET /api/v1/savings/custody/prepare'));
    expect(called, contains('POST /api/v1/savings/custody/claim'));
    // Sheet closed and the confirmation snackbar surfaced.
    expect(find.text('open'), findsOneWidget);
    expect(find.textContaining('Custody claimed'), findsWidgets);
  });

  testWidgets('a CONFLICT replay is treated as already claimed',
      (tester) async {
    container = ProviderContainer(
      overrides: [
        walletServiceProvider.overrideWithValue(
          WalletService(backends: [_FakeWalletBackend()]),
        ),
        apiClientProvider.overrideWithValue(ApiClient(
          baseUrl: 'http://x',
          httpClient: client(
            claimStatus: 409,
            claimBody: {
              'code': 'CONFLICT',
              'message': 'your savings address is already owned by your wallet',
            },
          ),
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
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => CustodyClaimSheet.show(context, _unclaimed()),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect wallet'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Claim custody with my wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claim custody with my wallet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('now owned by your wallet'), findsWidgets);
  });
}