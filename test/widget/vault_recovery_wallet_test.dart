import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/features/savings/presentation/pages/vault_recovery_page.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/savings_client.dart';
import 'package:globe_mint/shared/services/wallet_service.dart';

const _clone = '0x0925F132e9d44D70e6A106f173d8842c81765c51';
final _owner = '0x${'A' * 40}';
final _recovery = '0x${'B' * 40}';
const _chainId = 1337;
final _other = '0x${'C' * 40}';

/// A plain browser-wallet backend (no pairing): the injected path.
class _FakeInjectedBackend implements WalletBackend {
  _FakeInjectedBackend({String? address}) : address = address ?? _owner;

  String address;
  int chain = _chainId;

  @override
  String get name => 'MetaMask';

  @override
  bool isAvailable() => true;

  @override
  Future<List<String>> requestAccounts() async => [address];

  @override
  Future<List<String>> accounts() async => [address];

  @override
  Future<int> chainId() async => chain;

  @override
  Future<void> switchChain(int chainId) async {}

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) async =>
      '0xSig';
}

/// A controllable WalletConnect backend: pairing URI stream + session events,
/// approving the session only when the test completes the pending approval.
class _FakeWalletConnectBackend
    implements WalletBackend, WalletSessionEventsSource, WalletPairingProvider {
  final _events = StreamController<WalletConnectionEvent>.broadcast();
  final _pairing = StreamController<String>.broadcast();

  bool available = true;
  int disconnectCalls = 0;
  Object? rejectOnConnect;
  bool signExpiresOnce = false;
  Object? rejectOnSign;
  int chain = _chainId;
  bool unsupportedChain = false;
  Completer<List<String>>? pendingApproval;

  @override
  String get name => 'WalletConnect';

  @override
  bool isAvailable() => available;

  @override
  Stream<WalletConnectionEvent> get events => _events.stream;

  @override
  Stream<String> get pairingUris => _pairing.stream;

  @override
  Future<bool> launchPairingUri() async => true;

  /// Approve the currently-pending pairing with the owner account.
  void approve() {
    pendingApproval?.complete([_owner]);
    pendingApproval = null;
  }

  @override
  Future<List<String>> requestAccounts() async {
    if (rejectOnConnect != null) throw rejectOnConnect!;
    pendingApproval = Completer<List<String>>();
    _pairing.add('wc:pairing:test-uri');
    return pendingApproval!.future;
  }

  @override
  Future<List<String>> accounts() async => [_owner];

  @override
  Future<int> chainId() async => chain;

  @override
  Future<void> switchChain(int chainId) async {
    if (unsupportedChain) {
      throw const WalletConnectionException(
        'This wallet does not support chain 1337.',
        code: 'UNSUPPORTED_CHAIN',
      );
    }
    chain = chainId;
  }

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) async {
    if (signExpiresOnce) {
      signExpiresOnce = false;
      throw const WalletConnectionException(
        'Your wallet session ended while signing — please try again.',
        code: 'SESSION_EXPIRED',
      );
    }
    if (rejectOnSign != null) throw rejectOnSign!;
    return '0xSig';
  }

  @override
  Future<void> disconnectSession() async {
    disconnectCalls++;
  }
}

/// A netless [SavingsClient] that returns a static recovery status and records
/// every submitted designation.
class _FakeSavingsClient extends SavingsClient {
  _FakeSavingsClient() : super(ApiClient(baseUrl: 'http://x'));

  int prepareCount = 0;
  final List<String> submittedAddresses = [];
  final List<RecoverySignature> submittedSigs = [];

  @override
  Future<RecoveryStatus> getRecoveryStatus() async => RecoveryStatus(
        clone: _clone,
        owner: _owner,
        recoveryAddress: '',
        recoveryDelaySec: 0,
        recoveryRequestedAt: 0,
        recoveryAt: 0,
        recoveryPending: false,
      );

  @override
  Future<RecoveryQuote> prepareRecovery(String recoveryAddress) async {
    prepareCount++;
    return RecoveryQuote(
      domain: const Eip712Domain(
        name: 'GlobmintVault',
        version: '1',
        chainId: _chainId,
        verifyingContract: _clone,
      ),
      primaryType: 'SetRecovery',
      message: RecoveryMessage(
        recoveryAddress: recoveryAddress,
        nonce: prepareCount,
        deadline: 2000000000,
      ),
      cloneOwner: _owner,
    );
  }

  @override
  Future<RecoverySignatureResult> setRecoveryAddress({
    required String recoveryAddress,
    required RecoverySignature signature,
  }) async {
    submittedAddresses.add(recoveryAddress);
    submittedSigs.add(signature);
    return RecoverySignatureResult(
      recoveryAddress: recoveryAddress,
      txHash: '0xRecoveryTx',
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _FakeSavingsClient client, {
  required List<WalletBackend> backends,
}) async {
  final container = ProviderContainer(
    overrides: [
      walletServiceProvider.overrideWithValue(
        WalletService(backends: backends),
      ),
      savingsClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const VaultRecoveryPage(),
      ),
    ),
  );
  await _settle(tester);
  return container;
}

/// Pumps until the pairing/success dialogs and any in-flight spinner settle.
/// Bounded (not [WidgetTester.pumpAndSettle]) so indeterminate progress
/// indicators that legitimately outlive a frame-animation never hang the test.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('injected browser wallet signs and submits', (tester) async {
    final client = _FakeSavingsClient();
    await _pump(tester, client, backends: [_FakeInjectedBackend()]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    await _settle(tester);

    expect(client.submittedAddresses, [_recovery]);
    expect(client.submittedSigs.single.signature, '0xSig');
    expect(client.submittedSigs.single.nonce, 1);
    expect(find.text('Recovery Address Set'), findsOneWidget);
  });

  testWidgets('rejects when the connected wallet is not the clone owner',
      (tester) async {
    final client = _FakeSavingsClient();
    final other = _FakeInjectedBackend(address: _other);
    await _pump(tester, client, backends: [other]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(client.submittedAddresses, isEmpty);
    expect(find.textContaining('Connect the wallet that owns your savings'), findsOneWidget);
  });

  testWidgets('WalletConnect pairs via QR dialog, approves, signs, submits',
      (tester) async {
    final client = _FakeSavingsClient();
    final wc = _FakeWalletConnectBackend();
    await _pump(tester, client, backends: [wc]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The pairing dialog is up showing the fresh WC URI.
    expect(find.text('Scan with your wallet'), findsOneWidget);
    expect(wc.pendingApproval, isNotNull, reason: 'requestAccounts reached');

    // The wallet approves the session in the companion app.
    wc.approve();
    await _settle(tester);

    expect(client.submittedAddresses, [_recovery]);
    expect(find.text('Recovery Address Set'), findsOneWidget);
  });

  testWidgets('cancelling the pairing dialog abandons the session without signing',
      (tester) async {
    final client = _FakeSavingsClient();
    final wc = _FakeWalletConnectBackend();
    await _pump(tester, client, backends: [wc]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Scan with your wallet'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    expect(wc.disconnectCalls, 1);
    expect(client.submittedAddresses, isEmpty);
    expect(find.text('Scan with your wallet'), findsNothing);
  });

  testWidgets('wallet rejection during connect surfaces the cancelled copy',
      (tester) async {
    final client = _FakeSavingsClient();
    final wc = _FakeWalletConnectBackend()
      ..rejectOnConnect = const WalletConnectionException(
        'You rejected the session.',
        code: 'USER_REJECTED',
      );
    await _pump(tester, client, backends: [wc]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(client.submittedAddresses, isEmpty);
    expect(find.text('You cancelled the connection request.'), findsOneWidget);
  });

  testWidgets('a one-off expired session offers a reconnect that succeeds',
      (tester) async {
    final client = _FakeSavingsClient();
    final wc = _FakeWalletConnectBackend()
      ..signExpiresOnce = true;
    await _pump(tester, client, backends: [wc]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    wc.approve();
    await _settle(tester);

    // First signing attempt hit a dead session → reconnect prompt.
    expect(find.text('Session expired'), findsOneWidget);
    await tester.tap(find.text('Reconnect'));
    await _settle(tester);

    expect(client.submittedAddresses, [_recovery]);
    expect(find.text('Recovery Address Set'), findsOneWidget);
  });

  testWidgets('wrong chain offers a switch and signs once switched',
      (tester) async {
    final client = _FakeSavingsClient();
    final wc = _FakeWalletConnectBackend()..chain = 10;
    await _pump(tester, client, backends: [wc]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    wc.approve();
    await _settle(tester);

    expect(find.text('Switch network?'), findsOneWidget);
    await tester.tap(find.text('Switch'));
    await _settle(tester);

    expect(wc.chain, _chainId);
    expect(client.submittedAddresses, [_recovery]);
    expect(find.text('Recovery Address Set'), findsOneWidget);
  });

  testWidgets('an unsupported chain surfaces the wallet error and stops',
      (tester) async {
    final client = _FakeSavingsClient();
    final wc = _FakeWalletConnectBackend()
      ..chain = 10
      ..unsupportedChain = true;
    await _pump(tester, client, backends: [wc]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    wc.approve();
    await _settle(tester);

    expect(find.text('Switch network?'), findsOneWidget);
    await tester.tap(find.text('Switch'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(client.submittedAddresses, isEmpty);
    expect(
      find.text('This wallet does not support chain 1337.'),
      findsOneWidget,
    );
  });

  testWidgets('backend chooser appears with both and WalletConnect can be picked',
      (tester) async {
    final client = _FakeSavingsClient();
    final wc = _FakeWalletConnectBackend();
    await _pump(tester, client, backends: [
      _FakeInjectedBackend(),
      wc,
    ]);

    await tester.enterText(find.byType(TextField), _recovery);
    await tester.ensureVisible(find.text('Sign & Set Recovery Address'));
    await _settle(tester);
    await tester.tap(find.text('Sign & Set Recovery Address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Chooser lists both backends.
    expect(find.text('Connect a wallet'), findsOneWidget);
    expect(find.text('MetaMask'), findsOneWidget);
    expect(find.text('WalletConnect'), findsWidgets);

    await tester.tap(find.text('WalletConnect').first);
    await _settle(tester);
    expect(find.text('Scan with your wallet'), findsOneWidget);

    wc.approve();
    await _settle(tester);

    expect(client.submittedAddresses, [_recovery]);
    expect(find.text('Recovery Address Set'), findsOneWidget);
  });
}