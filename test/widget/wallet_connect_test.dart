import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/features/profile/presentation/widgets/wallet_connect_button.dart';
import 'package:globe_mint/shared/services/wallet_service.dart';

/// A controllable fake [WalletBackend] whose connect/sign calls resolve
/// immediately unless a [Completer] is injected to hold them open, letting
/// tests simulate in-flight connection/signing and mid-flight disconnects.
class _FakeWalletBackend implements WalletBackend {
  _FakeWalletBackend();

  List<String> accountsToReturn = const ['0xAAAA'];
  int chainToReturn = 1337;
  Object? throwable;
  Completer<String>? signCompleter;

  @override
  String get name => 'Fake';

  @override
  bool isAvailable() => true;

  @override
  Future<List<String>> requestAccounts() async {
    if (throwable != null) throw throwable!;
    return accountsToReturn;
  }

  @override
  Future<List<String>> accounts() async => accountsToReturn;

  @override
  Future<int> chainId() async => chainToReturn;

  @override
  Future<void> switchChain(int chainId) async {
    if (throwable != null) throw throwable!;
    chainToReturn = chainId;
  }

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) async {
    if (throwable != null) throw throwable!;
    if (signCompleter != null) return signCompleter!.future;
    return '0xSig';
  }
}

/// A minimal harness rendering the real [WalletConnectButton] plus the live
/// wallet address so tests can assert what the provider actually holds.
class _Harness extends ConsumerWidget {
  const _Harness({this.expectedChainId});

  final int? expectedChainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text(wallet.isConnected ? (wallet.address ?? '') : 'not connected'),
            if (wallet.signing) const Text('signing…'),
            if (wallet.status == WalletConnectionStatus.connecting)
              const Text('connecting…'),
            if (wallet.status == WalletConnectionStatus.wrongChain)
              const Text('wrong chain'),
            WalletConnectButton(expectedChainId: expectedChainId),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWalletBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = _FakeWalletBackend();
    container = ProviderContainer(
      overrides: [
        walletServiceProvider.overrideWithValue(
          WalletService(backends: [backend]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  testWidgets('tapping "Connect wallet" with a mocked provider connects',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Harness()),
    );

    expect(find.text('not connected'), findsOneWidget);
    expect(find.text('Connect wallet'), findsOneWidget);

    await tester.tap(find.text('Connect wallet'));
    await tester.pumpAndSettle();

    expect(find.text('0xAAAA'), findsOneWidget);
    expect(find.text('Connect wallet'), findsNothing);
    expect(find.text('Disconnect'), findsOneWidget);
  });

  testWidgets('connecting and signing states render busy UI', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Harness()),
    );
    await tester.tap(find.text('Connect wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect'), findsOneWidget);

    final signCom = Completer<String>();
    backend.signCompleter = signCom;

    // Start a real-async sign so the pending completer lives outside FakeAsync
    // (which never drains the pending microtask otherwise).
    late Future<String> signing;
    await tester.runAsync(() async {
      signing = container.read(walletProvider.notifier).signTypedData({
        'types': <String, dynamic>{},
        'domain': <String, dynamic>{
          'verifyingContract': '0x0000000000000000000000000000000000000001',
        },
        'message': <String, dynamic>{'to': '0xBBB', 'amount': '100'},
        'primaryType': 'WithdrawRequest',
      });
    });
    expect(container.read(walletProvider).signing, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Signing…'), findsOneWidget);

    await tester.runAsync(() async {
      signCom.complete('0xSig');
      expect(await signing, '0xSig');
    });
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.read(walletProvider).signing, isFalse);
    expect(find.text('Signing…'), findsNothing);
  });

  testWidgets('mid-flow disconnect clears the signing pending UI',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Harness()),
    );
    await tester.tap(find.text('Connect wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect'), findsOneWidget);

    final signCom = Completer<String>();
    backend.signCompleter = signCom;

    late Future<String> signing;
    await tester.runAsync(() async {
      signing = container.read(walletProvider.notifier).signTypedData({
        'types': <String, dynamic>{},
        'domain': <String, dynamic>{
          'verifyingContract': '0x0000000000000000000000000000000000000002',
        },
        'message': <String, dynamic>{'to': '0xBBB', 'amount': '100'},
        'primaryType': 'WithdrawRequest',
      });
    });
    expect(container.read(walletProvider).signing, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Signing…'), findsOneWidget);

    // The wallet disconnects (extension cleared / user reloaded) while the
    // signature request is still pending in the wallet UI.
    await tester.runAsync(
        () => container.read(walletProvider.notifier).disconnect());
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('not connected'), findsOneWidget);
    expect(find.text('Signing…'), findsNothing);
    expect(container.read(walletProvider).signing, isFalse);

    // Completing the stale signature must not resurrect connection state.
    await tester.runAsync(() async {
      signCom.complete('0xStaleSig');
      try {
        await signing;
        fail('stale signature should have been rejected');
      } on WalletConnectionException {
        // expected: mid-flight disconnect invalidates the pending signature.
      }
    });
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('not connected'), findsOneWidget);
    expect(container.read(walletProvider).signing, isFalse);
  });

  testWidgets('wrong network offers to switch and recovers', (tester) async {
    backend.chainToReturn = 10;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _Harness(expectedChainId: 1337),
      ),
    );
    await tester.tap(find.text('Connect wallet'));
    await tester.pumpAndSettle();

    // The connect pins to 1337, the wallet is on 10, so the button reflects
    // the wrong-chain state and auto-offers the switch dialog.
    expect(find.text('Switch network'), findsOneWidget);
    expect(find.text('wrong chain'), findsOneWidget);
    expect(find.text('Switch network?'), findsOneWidget);

    // Confirm the dialog asks the wallet to switch.
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();

    expect(backend.chainToReturn, 1337);
    expect(find.text('Switch network?'), findsNothing);
    expect(find.text('0xAAAA'), findsOneWidget);
  });
}