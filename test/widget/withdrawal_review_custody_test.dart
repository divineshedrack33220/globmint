import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/features/savings/presentation/pages/withdrawal_review_page.dart';
import 'package:globe_mint/shared/models/models.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/conversion_service.dart';
import 'package:globe_mint/shared/services/savings_client.dart';
import 'package:globe_mint/shared/services/wallet_service.dart';

const _clone = '0x0925F132e9d44D70e6A106f173d8842c81765c51';
const _placeholder = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
const _wallet = '0xAAAA';

class _FakeWalletBackend implements WalletBackend {
  @override
  String get name => 'Fake';

  @override
  bool isAvailable() => true;

  @override
  Future<List<String>> requestAccounts() async => const [_wallet];

  @override
  Future<List<String>> accounts() async => const [_wallet];

  @override
  Future<int> chainId() async => 1337;

  @override
  Future<void> switchChain(int chainId) async {}

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) async =>
      '0xSig';
}

/// A netless [SavingsClient] that simulates an unclaimed-then-claimed clone:
/// before custody the owner seat is the platform placeholder (nonce 0); after a
/// `claimCustody` the clone is owned by the wallet (nonce 1).
class _FakeSavingsClient extends SavingsClient {
  _FakeSavingsClient(this.info) : super(ApiClient(baseUrl: 'http://x'));

  final DepositInfo info;
  bool custodyClaimed = false;
  int prepareCount = 0;
  final List<WithdrawSignature?> submitted = [];

  @override
  Future<DepositInfo> getDepositInfo() async => info;

  @override
  Future<CustodyStatus> getCustodyStatus() async => CustodyStatus(
        clone: _clone,
        owner: custodyClaimed ? _wallet : _placeholder,
        placeholder: _placeholder,
        claimed: custodyClaimed,
        nonce: custodyClaimed ? 1 : 0,
      );

  @override
  Future<WithdrawQuote> prepareWithdrawal({
    required String amount,
    required String destination,
  }) async {
    prepareCount++;
    final owner = custodyClaimed ? _wallet : _placeholder;
    return WithdrawQuote(
      domain: const Eip712Domain(
        name: 'GlobmintVault',
        version: '1',
        chainId: 1337,
        verifyingContract: _clone,
      ),
      primaryType: 'WithdrawRequest',
      message: QuoteMessage(
        to: destination,
        amount: '100000000',
        nonce: custodyClaimed ? 1 : 0,
        deadline: 2000000000,
      ),
      amountNgnMinor: 100000,
      feeNgnMinor: 200,
      amountMinorBase: '100000000',
      cloneOwner: owner,
    );
  }

  @override
  Future<CustodyQuote> prepareCustody(String newOwner) async =>
      const CustodyQuote(
        domain: Eip712Domain(
          name: 'GlobmintVault',
          version: '1',
          chainId: 1337,
          verifyingContract: _clone,
        ),
        primaryType: 'TransferOwnership',
        message: CustodyMessage(
          newOwner: _wallet,
          nonce: 0,
          deadline: 2000000000,
        ),
        cloneOwner: _placeholder,
      );

  @override
  Future<CustodyClaimResult> claimCustody(String newOwner) async {
    custodyClaimed = true;
    return CustodyClaimResult(
      claimed: true,
      newOwner: newOwner,
      txHash: '0xClaim',
    );
  }

  @override
  Future<WithdrawResult> withdrawToAddress({
    required String amount,
    required String destination,
    required String pin,
    WithdrawSignature? signature,
  }) async {
    submitted.add(signature);
    return const WithdrawResult(txHash: '0xTX', elevation: null);
  }
}

DepositInfo _info() => DepositInfo(
      address: _clone,
      vaultContract: '0xVault',
      stablecoinSymbol: 'USDC',
      stablecoinName: 'USD Coin',
      stablecoinDecimals: 6,
      stablecoinContract: '0xUsdc',
      network: 'hardhat',
      chainId: 1337,
      mode: 'vault',
      requireUserSignature: true,
    );

/// Netless rate quote so the review page's `_loadQuote` never awaits real HTTP
/// (which can't settle under the fake-async test zone).
class _FakeConversionService extends ConversionService {
  _FakeConversionService() : super(ApiClient(baseUrl: 'http://x'));

  @override
  Future<ConversionQuote> getQuote({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    return ConversionQuote(
      inputAmount: amount,
      inputCurrency: fromCurrency,
      outputAmount: amount / 1500,
      outputCurrency: toCurrency,
      rate: 1500,
      fee: 0,
      feeAmount: 0,
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );
  }
}

Future<ProviderContainer> _pumpReview(
  WidgetTester tester,
  _FakeSavingsClient client,
  _FakeWalletBackend backend, {
  bool claimed = false,
}) async {
  client.custodyClaimed = claimed;
  final container = ProviderContainer(
    overrides: [
      walletServiceProvider
          .overrideWithValue(WalletService(backends: [backend])),
      savingsClientProvider.overrideWithValue(client),
      conversionServiceProvider.overrideWithValue(_FakeConversionService()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const WithdrawalReviewPage(
          amount: 1000,
          destination: '0x1111111111111111111111111111111111111111',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unclaimed custody gates signing and re-quotes after the claim',
      (tester) async {
    final client = _FakeSavingsClient(_info());
    await _pumpReview(tester, client, _FakeWalletBackend(), claimed: false);

    expect(find.textContaining('platform placeholder'), findsWidgets);

    await tester.tap(find.text('Connect & Sign Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Finalize withdrawal?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // The custody gate opens the claim sheet instead of attempting a doomed
    // platform-owner signature.
    expect(find.text('Current owner'), findsOneWidget);
    await tester.tap(find.text('Connect wallet'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Claim custody with my wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claim custody with my wallet'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Claim succeeded, custody provider refreshed, signing re-quoted for the
    // bumped nonce, and the withdrawal was submitted under the NEW nonce.
    expect(client.custodyClaimed, isTrue);
    expect(client.prepareCount, greaterThanOrEqualTo(2));
    expect(client.submitted, hasLength(1));
    expect(client.submitted.first, isNotNull);
    expect(client.submitted.first!.nonce, 1);
    expect(find.text('Withdrawal Sent'), findsOneWidget);
  });

  testWidgets('a claimed clone signs straight through with no re-quote',
      (tester) async {
    final client = _FakeSavingsClient(_info());
    await _pumpReview(tester, client, _FakeWalletBackend(), claimed: true);
    final preparesAtStart = client.prepareCount;

    await tester.tap(find.text('Connect & Sign Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Finalize withdrawal?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(client.prepareCount, preparesAtStart);
    expect(client.submitted, hasLength(1));
    expect(client.submitted.first!.nonce, 1);
    expect(find.text('Withdrawal Sent'), findsOneWidget);
  });
}