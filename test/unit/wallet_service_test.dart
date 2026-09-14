import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/wallet_service.dart';

/// A controllable mock wallet backend used to exercise [WalletService] and the
/// Riverpod [walletProvider] without a real browser wallet.
class _MockWalletBackend implements WalletBackend {
  _MockWalletBackend();

  List<String> accountsToReturn = const ['0xAAAA'];
  int chainToReturn = 1337;

  /// When non-null, [requestAccounts] / [switchChain] / [signTypedDataV4] will
  /// throw this error instead of succeeding.
  Object? throwable;

  /// Completer the test can .complete() to simulate a hanging sign call.
  Completer<String>? signCompleter;

  @override
  String get name => 'Mock';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletService', () {
    late _MockWalletBackend mock;
    late WalletService service;

    setUp(() {
      mock = _MockWalletBackend();
      service = WalletService(backends: [mock]);
    });

    test('connect sets connected state with address and chain', () async {
      final state = await service.connect();
      expect(state.status, WalletConnectionStatus.connected);
      expect(state.address, '0xAAAA');
      expect(state.chainId, 1337);
      expect(service.current.status, WalletConnectionStatus.connected);
    });

    test('connect throws WalletUnavailableException when no backend is available', () async {
      final empty = WalletService(backends: []);
      expect(
        () => empty.connect(),
        throwsA(isA<WalletUnavailableException>()),
      );
      expect(empty.current.status, WalletConnectionStatus.disconnected);
    });

    test('connect rejects when requestAccounts returns empty', () async {
      mock.accountsToReturn = [];
      try {
        await service.connect();
        fail('should have thrown');
      } on WalletConnectionException {
        // expected
      }
      expect(service.current.status, WalletConnectionStatus.disconnected);
    });

    test('connect emits wrongChain when expected chain differs', () async {
      mock.chainToReturn = 10;
      try {
        await service.connect(expectedChainId: 1);
        fail('should have thrown');
      } on WalletWrongChainException {
        // expected
      }
      expect(service.current.status, WalletConnectionStatus.wrongChain);
      expect(service.current.chainId, 10);
      expect(service.current.expectedChainId, 1);
    });

    test('ensureChain switches the wallet chain on success', () async {
      await service.connect();
      mock.chainToReturn = 421614;
      final state = await service.ensureChain(421614);
      expect(state.status, WalletConnectionStatus.connected);
      expect(state.chainId, 421614);
    });

    test('disconnect resets state to disconnected', () async {
      await service.connect();
      await service.disconnect();
      expect(service.current.status, WalletConnectionStatus.disconnected);
    });
  });

  group('signTypedData validation', () {
    late _MockWalletBackend mock;
    late WalletService service;

    setUp(() {
      mock = _MockWalletBackend();
      service = WalletService(backends: [mock]);
    });

    test('throws ApiException(400) for missing types key', () async {
      await service.connect();
      expect(
        () => service.signTypedData({'domain': {}, 'message': {}, 'primaryType': 'X'}),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_TYPED_DATA')),
      );
    });

    test('throws ApiException(400) for empty primaryType', () async {
      await service.connect();
      expect(
        () => service.signTypedData({
          'types': {},
          'domain': {'verifyingContract': '0x0000000000000000000000000000000000000001'},
          'message': {},
          'primaryType': '',
        }),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_TYPED_DATA')),
      );
    });

    test('throws ApiException(400) for bad verifyingContract address', () async {
      await service.connect();
      expect(
        () => service.signTypedData({
          'types': {},
          'domain': {'verifyingContract': 'not-an-address'},
          'message': {'a': 1},
          'primaryType': 'Foo',
        }),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_TYPED_DATA')),
      );
    });

    test('throws ApiException(400) for empty message', () async {
      await service.connect();
      expect(
        () => service.signTypedData({
          'types': {},
          'domain': {'verifyingContract': '0x0000000000000000000000000000000000000001'},
          'message': <String, dynamic>{},
          'primaryType': 'Foo',
        }),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_TYPED_DATA')),
      );
    });

    test('returns the wallet signature when the payload is valid', () async {
      await service.connect();
      final sig = await service.signTypedData({
        'types': {'EIP712Domain': []},
        'domain': {'verifyingContract': '0x0000000000000000000000000000000000000001'},
        'message': {'to': '0xBBB', 'amount': '100'},
        'primaryType': 'WithdrawRequest',
      });
      expect(sig, '0xSig');
    });
  });

  group('WalletNotifier via Riverpod', () {
    late _MockWalletBackend mock;
    late ProviderContainer container;

    setUp(() {
      mock = _MockWalletBackend();
      container = ProviderContainer(
        overrides: [
          walletServiceProvider.overrideWithValue(WalletService(backends: [mock])),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('connect updates walletProvider state to connected', () async {
      final notifier = container.read(walletProvider.notifier);
      await notifier.connect();
      final state = container.read(walletProvider);
      expect(state.status, WalletConnectionStatus.connected);
      expect(state.address, '0xAAAA');
      expect(state.chainId, 1337);
    });

    test('wrong chain sets wrongChain status and surfaces error', () async {
      mock.chainToReturn = 10;
      final notifier = container.read(walletProvider.notifier);
      try {
        await notifier.connect(expectedChainId: 1);
        fail('should have thrown');
      } on WalletWrongChainException {
        // expected
      }
      final state = container.read(walletProvider);
      expect(state.status, WalletConnectionStatus.wrongChain);
      expect(state.error, isNotNull);
    });

    test('disconnect clears connected state', () async {
      final notifier = container.read(walletProvider.notifier);
      await notifier.connect();
      expect(container.read(walletProvider).isConnected, isTrue);
      await notifier.disconnect();
      expect(container.read(walletProvider).isConnected, isFalse);
    });
  });

  group('mid-flow disconnect', () {
    test('signing flag clears and throws when wallet disconnects during sign', () async {
      final mock = _MockWalletBackend();
      final signCom = Completer<String>();
      mock.signCompleter = signCom;
      final service = WalletService(backends: [mock]);
      final container = ProviderContainer(
        overrides: [walletServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(walletProvider.notifier).connect();

      // Start a signing call that blocks on the mock.
      final signFuture = container.read(walletProvider.notifier).signTypedData({
        'types': {},
        'domain': {'verifyingContract': '0x0000000000000000000000000000000000000001'},
        'message': {'to': '0xBBB', 'amount': '100'},
        'primaryType': 'WithdrawRequest',
      });

      // Give the test a tick so signTypedData hits the await.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(container.read(walletProvider).signing, isTrue);

      // The service emits disconnected externally (user reloaded the wallet /
      // extension popup closed) while the sign call is hanging.
      await service.disconnect();
      // The notifier mirrors it: signing should now be false.
      expect(container.read(walletProvider).signing, isFalse);

      // Complete the mock sign — the mid-flight guard should discard it.
      signCom.complete('0xStaleSig');
      expect(
        signFuture,
        throwsA(isA<WalletConnectionException>()),
      );
    });
  });
}