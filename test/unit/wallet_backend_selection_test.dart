import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:globe_mint/shared/services/wallet_service.dart';

class _MockWalletBackend implements WalletBackend {
  _MockWalletBackend(this.tag);

  final String tag;
  bool available = true;
  int requestAccountsCalls = 0;
  int switchChainCalls = 0;

  @override
  String get name => 'Mock-$tag';

  @override
  bool isAvailable() => available;

  @override
  Future<List<String>> requestAccounts() async {
    requestAccountsCalls++;
    return ['0x1111_$tag'];
  }

  @override
  Future<List<String>> accounts() async => ['0x1111_$tag'];

  @override
  Future<int> chainId() async => 11155111;

  @override
  Future<void> switchChain(int chainId) async {
    switchChainCalls++;
  }

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) async =>
      '0xSig';
}

class _MockSessionBackend extends _MockWalletBackend
    implements WalletSessionEventsSource {
  _MockSessionBackend(super.tag);

  final _events = StreamController<WalletConnectionEvent>.broadcast();
  int disconnectCalls = 0;

  @override
  Stream<WalletConnectionEvent> get events => _events.stream;

  @override
  Future<void> disconnectSession() async {
    disconnectCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletService backend selection', () {
    test('availableBackends only lists available backends', () {
      final injected = _MockWalletBackend('injected');
      final wc = _MockWalletBackend('wc')..available = false;
      final service = WalletService(backends: [injected, wc]);

      expect(service.availableBackends, hasLength(1));
      expect(service.availableBackends.single, same(injected));
    });

    test('defaultBackend keeps the active backend while available', () async {
      final injected = _MockWalletBackend('injected');
      final wc = _MockSessionBackend('wc');
      final service = WalletService(backends: [injected, wc]);

      expect(service.defaultBackend, isNot(same(wc)));

      await service.connect(backend: wc);
      expect(service.activeBackend, same(wc));
      // After connecting through WalletConnect the default keeps it, even
      // though a browser backend slots first in selection order.
      expect(service.defaultBackend, same(wc));
    });

    test('connect pins to the requested backend', () async {
      final injected = _MockWalletBackend('injected');
      final wc = _MockSessionBackend('wc');
      final service = WalletService(backends: [injected, wc]);

      await service.connect(backend: wc);

      expect(wc.requestAccountsCalls, 1);
      expect(injected.requestAccountsCalls, 0);
      expect(service.current.address, '0x1111_wc');
      expect(service.activeBackend, same(wc));
    });

    test('disconnect tears down the WalletSessionEventsSource session',
        () async {
      final wc = _MockSessionBackend('wc');
      final service = WalletService(backends: [wc]);
      await service.connect();
      expect(wc.disconnectCalls, 0);

      await service.disconnect();

      expect(wc.disconnectCalls, 1);
      expect(service.activeBackend, isNull);
      expect(service.current.status, WalletConnectionStatus.disconnected);
    });

    test('a plain backend disconnect stays non-fatal', () async {
      final plain = _MockWalletBackend('plain');
      final service = WalletService(backends: [plain]);
      await service.connect();
      await service.disconnect();
      expect(service.current.status, WalletConnectionStatus.disconnected);
    });
  });

  group('WalletService backend events', () {
    test('sessionExpired flips connected state to disconnected', () async {
      final wc = _MockSessionBackend('wc');
      final service = WalletService(backends: [wc]);
      await service.connect(expectedChainId: 11155111);
      expect(service.current.status, WalletConnectionStatus.connected);

      wc.emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.sessionExpired,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(service.current.status, WalletConnectionStatus.disconnected);
    });

    test('accountChanged updates the connected address', () async {
      final wc = _MockSessionBackend('wc');
      final service = WalletService(backends: [wc]);
      await service.connect(expectedChainId: 11155111);

      wc.emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.accountChanged,
        address: '0xNewOwner',
        chainId: 11155111,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(service.current.address, '0xNewOwner');
      expect(service.current.status, WalletConnectionStatus.connected);
    });

    test('chainChanged to a different chain flips to wrongChain', () async {
      final wc = _MockSessionBackend('wc');
      final service = WalletService(backends: [wc]);
      await service.connect(expectedChainId: 11155111);

      wc.emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.chainChanged,
        chainId: 10,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(service.current.status, WalletConnectionStatus.wrongChain);
      expect(service.current.chainId, 10);
      expect(service.current.expectedChainId, 11155111);
    });

    test('chainChanged back to the expected chain restores connected',
        () async {
      final wc = _MockSessionBackend('wc');
      final service = WalletService(backends: [wc]);
      await service.connect(expectedChainId: 11155111);

      wc.emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.chainChanged,
        chainId: 10,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(service.current.status, WalletConnectionStatus.wrongChain);

      wc.emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.chainChanged,
        chainId: 11155111,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(service.current.status, WalletConnectionStatus.connected);
      expect(service.current.chainId, 11155111);
    });
  });
}

extension _Emit on _MockSessionBackend {
  void emitEvent(WalletConnectionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}