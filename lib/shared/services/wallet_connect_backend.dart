import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:reown_core/reown_core.dart'
    show JsonRpcError, LogLevel, PairingMetadata;
import 'package:reown_sign/reown_sign.dart'
    show
        Namespace,
        ReownSignClient,
        ReownSignError,
        RequiredNamespace,
        SessionData,
        SessionRequestParams;
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'wallet_service.dart';

/// WalletConnect v2 backend (the **dapp** role of the protocol).
///
/// The app initiates a WalletConnect session (pairing URI → QR on web,
/// wallet-app deep link on mobile), waits for the user to approve it in their
/// wallet, then signs the same EIP-712 payloads the injected backend signs —
/// [`WalletService`] swaps [WalletSessionEventsSource], the URI stream, and the
/// transport; nothing downstream changes.
///
/// **Why `reown_sign` and not `reown_walletkit`:** WalletKit implements the
/// *wallet* side (approving session proposals, answering incoming requests).
/// A dapp that starts sessions and sends `eth_signTypedData_v4` is the Sign
/// client (`ReownSignClient`), which is what this backend wraps. `reown_sign`
/// also carries `reown_walletkit` transitively.
class WalletConnectWalletBackend
    implements WalletBackend, WalletSessionEventsSource, WalletPairingProvider {
  WalletConnectWalletBackend();

  /// Injected at build time only, via
  /// `--dart-define=WALLETCONNECT_PROJECT_ID=…`. Never read from a file and
  /// never logged. Empty (missing define) → every entry point throws the typed
  /// `WALLET_NOT_AVAILABLE` [ApiException] instead of misbehaving.
  static const String projectId = String.fromEnvironment(
    'WALLETCONNECT_PROJECT_ID',
  );

  /// The chains GlobMint signs on and allows a session to approve: the
  /// Sepolia deployment plus the L2 groundwork from README §9.4 (Base, Base
  /// Sepolia, Arbitrum One, Arbitrum Sepolia, Optimism, Optimism Sepolia).
  /// A session scoped to exactly this allowlist cannot be approved on any
  /// other network, so a wallet on an unknown chain fails closed.
  static const Set<int> supportedChainIds = {
    11155111, // Sepolia
    8453, // Base
    84532, // Base Sepolia
    42161, // Arbitrum One
    421614, // Arbitrum Sepolia
    10, // Optimism
    11155420, // Optimism Sepolia
  };

  static const List<String> _methods = [
    'eth_sendTransaction',
    'personal_sign',
    'eth_signTypedData',
    'eth_signTypedData_v3',
    'eth_signTypedData_v4',
  ];

  static const List<String> _events = ['chainChanged', 'accountsChanged'];

  ReownSignClient? _client;
  SessionData? _session;
  String? _topic;
  List<String> _accounts = const [];
  int _chainId = 0;
  bool _eventsWired = false;

  final StreamController<String> _pairingUris =
      StreamController<String>.broadcast();
  String? _latestPairingUri;
  final StreamController<WalletConnectionEvent> _eventsCtrl =
      StreamController<WalletConnectionEvent>.broadcast();

  /// Fresh pairing URIs, one per new session. The web UI renders them as a QR
  /// code; mobile deep-links into the wallet app. New subscribers immediately
  /// receive the latest URI (if any) so a late-binding QR dialog never starts
  /// blank.
  @override
  Stream<String> get pairingUris async* {
    final latest = _latestPairingUri;
    if (latest != null) yield latest;
    yield* _pairingUris.stream;
  }

  /// Whether an approved session is currently live (re-entering the app skips
  /// the pairing modal and reuses it).
  bool get hasActiveSession => _session != null;

  @override
  Stream<WalletConnectionEvent> get events => _eventsCtrl.stream;

  @override
  String get name => 'WalletConnect';

  @override
  bool isAvailable() {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        // Desktop has no companion wallet target; the injected backend (or
        // nothing) covers it.
        return false;
    }
  }

  Future<ReownSignClient> _clientOrThrow() async {
    if (projectId.isEmpty) {
      throw ApiException(
        0,
        'Wallet signing is not enabled in this build. Rebuild with '
        '--dart-define=WALLETCONNECT_PROJECT_ID=… to connect a wallet.',
        code: 'WALLET_NOT_AVAILABLE',
      );
    }
    final existing = _client;
    if (existing != null) return existing;
    final client = await ReownSignClient.createInstance(
      projectId: projectId,
      metadata: const PairingMetadata(
        name: 'GlobMint',
        description: 'Personal digital savings platform',
        url: 'https://globmint.local',
        icons: [],
      ),
      memoryStore: false,
      logLevel: LogLevel.nothing,
    );
    _client = client;
    _wireEvents(client);
    return client;
  }

  /// Bridges wallet-side session activity into the [WalletService] state
  /// machine so expiry/account/chain changes surface without a user action.
  void _wireEvents(ReownSignClient client) {
    if (_eventsWired) return;
    _eventsWired = true;
    client.onSessionDelete.subscribe((e) {
      if (e.topic != _topic || _session == null) return;
      _clearSession();
      _emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.sessionExpired,
      ));
    });
    client.onSessionExpire.subscribe((e) {
      if (e.topic != _topic || _session == null) return;
      _clearSession();
      _emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.sessionExpired,
      ));
    });
    client.onSessionUpdate.subscribe((e) {
      if (e.topic != _topic || _session == null) return;
      _reconcile(e.namespaces);
    });
    client.onSessionEvent.subscribe((e) {
      if (e.topic != _topic || _session == null) return;
      if (e.name == 'accountsChanged') {
        final list = e.data;
        if (list is List) {
          final accounts = list
              .map((a) => a.toString())
              .where((a) => a.isNotEmpty)
              .toList();
          if (!_sameAccounts(_accounts, accounts)) {
            _accounts = accounts;
            _emitEvent(WalletConnectionEvent(
              type: WalletConnectionEventType.accountChanged,
              address: accounts.isEmpty ? null : accounts.first,
              chainId: _chainId,
            ));
          }
        }
      } else if (e.name == 'chainChanged') {
        final raw = e.data?.toString() ?? '';
        final chain = _parseHexOrDec(raw);
        if (chain != 0 && chain != _chainId) {
          _chainId = chain;
          _emitEvent(WalletConnectionEvent(
            type: WalletConnectionEventType.chainChanged,
            chainId: chain,
          ));
        }
      }
    });
  }

  void _emitEvent(WalletConnectionEvent event) {
    if (!_eventsCtrl.isClosed) _eventsCtrl.add(event);
  }

  void _clearSession() {
    _topic = null;
    _session = null;
    _accounts = const [];
    _chainId = 0;
  }

  /// Snapshot of the approved session's accounts + chain for relays from the
  /// wallet (namespace updates, `accountsChanged`/`chainChanged` events).
  void _reconcile(Map<String, Namespace> namespaces) {
    final accounts = _accountsFrom(namespaces);
    final chain = _chainFrom(namespaces);
    final accountsChanged = !_sameAccounts(_accounts, accounts);
    final chainChanged = chain != 0 && chain != _chainId;
    if (accountsChanged) _accounts = accounts;
    if (chainChanged) _chainId = chain;
    if (accountsChanged) {
      _emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.accountChanged,
        address: accounts.isEmpty ? null : accounts.first,
        chainId: chain == 0 ? _chainId : chain,
      ));
    } else if (chainChanged) {
      _emitEvent(WalletConnectionEvent(
        type: WalletConnectionEventType.chainChanged,
        chainId: chain,
      ));
    }
  }

  static List<String> _accountsFrom(Map<String, Namespace> namespaces) {
    final ns = namespaces['eip155'];
    if (ns == null) return const [];
    return ns.accounts
        .map((a) => a.split(':').last)
        .where((a) => a.isNotEmpty)
        .toList();
  }

  static int _chainFrom(Map<String, Namespace> namespaces) {
    final ns = namespaces['eip155'];
    if (ns == null) return 0;
    final chains = ns.chains;
    if (chains != null && chains.isNotEmpty) return _parseChainId(chains.first);
    final accounts = ns.accounts;
    if (accounts.isNotEmpty) {
      final parts = accounts.first.split(':');
      if (parts.length == 3) return _parseChainId(parts.last);
    }
    return 0;
  }

  static int _parseChainId(String caip) {
    final parts = caip.split(':');
    return _parseHexOrDec(parts.isEmpty ? '' : parts.last);
  }

  static int _parseHexOrDec(String raw) {
    if (raw.startsWith('0x') || raw.startsWith('0X')) {
      return int.tryParse(raw.substring(2), radix: 16) ?? 0;
    }
    return int.tryParse(raw) ?? 0;
  }

  static bool _sameAccounts(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = a.map((x) => x.toLowerCase()).toList()..sort();
    final sortedB = b.map((x) => x.toLowerCase()).toList()..sort();
    for (var i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  @override
  Future<List<String>> requestAccounts() async {
    final client = await _clientOrThrow();
    if (_session != null) return _accounts.toList();

    // Re-entry after a reload: reuse an already-approved session rather than
    // forcing a fresh pairing.
    for (final session in client.getActiveSessions().values) {
      _session = session;
      _topic = session.topic;
      _reconcile(session.namespaces);
      if (_accounts.isNotEmpty) return _accounts.toList();
      _clearSession();
    }

    final connect = await client.connect(
      optionalNamespaces: {
        'eip155': RequiredNamespace(
          chains: supportedChainIds.map((id) => 'eip155:$id').toList(),
          methods: _methods,
          events: _events,
        ),
      },
    );

    final uri = connect.uri;
    if (uri != null && !_pairingUris.isClosed) {
      _latestPairingUri = uri.toString();
      _pairingUris.add(_latestPairingUri!);
    }

    try {
      final session = await connect.session.future;
      _session = session;
      _topic = session.topic;
      _reconcile(session.namespaces);
      if (_accounts.isEmpty) {
        throw const WalletConnectionException(
          'No account was returned by the wallet.',
        );
      }
      return _accounts.toList();
    } catch (e) {
      if (e is WalletConnectionException) rethrow;
      // Wallet declined the proposal (or it expired before scanning).
      throw const WalletConnectionException(
        'You cancelled the connection request (WalletConnect).',
        code: 'USER_REJECTED',
      );
    }
  }

  @override
  Future<List<String>> accounts() async {
    await _clientOrThrow();
    return _accounts.toList();
  }

  @override
  Future<int> chainId() async {
    await _clientOrThrow();
    return _chainId;
  }

  @override
  Future<void> switchChain(int chainId) async {
    if (!supportedChainIds.contains(chainId)) {
      throw const WalletConnectionException(
        'GlobMint does not support this network through WalletConnect.',
        code: 'UNSUPPORTED_CHAIN',
      );
    }
    final client = await _clientOrThrow();
    final topic = _topic;
    if (topic == null || _session == null) {
      _chainId = chainId;
      return;
    }
    try {
      await client.request(
        topic: topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': '0x${chainId.toRadixString(16)}'},
          ],
        ),
      );
      _chainId = chainId;
    } on WalletConnectionException {
      rethrow;
    } catch (_) {
      throw WalletConnectionException(
        'Your wallet did not switch networks. Switch it to chain $chainId '
        'in your wallet app and try again.',
        code: 'UNSUPPORTED_CHAIN',
      );
    }
  }

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) async {
    final client = await _clientOrThrow();
    final topic = _topic;
    if (topic == null || _session == null) {
      throw const WalletConnectionException(
        'Your wallet session is gone — reconnect and try again.',
        code: 'SESSION_EXPIRED',
      );
    }
    if (!_accounts.any((a) => a.toLowerCase() == from.toLowerCase())) {
      throw const WalletConnectionException(
        'Connect the wallet that owns your savings address to sign.',
        code: 'CONNECTION_FAILED',
      );
    }
    try {
      final result = await client.request(
        topic: topic,
        chainId: 'eip155:$_chainId',
        request: SessionRequestParams(
          method: 'eth_signTypedData_v4',
          params: [from, typedDataJson],
        ),
      );
      if (result is! String || !result.startsWith('0x')) {
        throw const WalletSignatureException(
          'The wallet returned an unusable signature.',
          code: 'SIGNATURE_REJECTED',
        );
      }
      return result;
    } on WalletConnectionException {
      rethrow;
    } on WalletSignatureException {
      rethrow;
    } catch (e) {
      if (e is JsonRpcError && e.code != null && _isUserRejection(e.code!)) {
        throw const WalletSignatureException(
          'You cancelled the request in your wallet.',
          code: 'USER_REJECTED',
        );
      }
      // Signature not produced and no explicit rejection: the session is most
      // likely gone (relay error / wallet closed mid-review).
      throw const WalletConnectionException(
        'Your wallet session ended while signing — reconnect and try again.',
        code: 'SESSION_EXPIRED',
      );
    }
  }

  /// WalletConnect user-rejection codes (USER_REJECTED / _CHAINS / _METHODS /
  /// _EVENTS / _AUTH) sit in the 5xxx range; MetaMask uses 4001.
  static bool _isUserRejection(int code) => code >= 4000 && code < 6000;

  @override
  Future<void> disconnectSession() async {
    final topic = _topic;
    final client = _client;
    _clearSession();
    if (topic == null || client == null) return;
    try {
      await client.disconnect(
        topic: topic,
        reason: const ReownSignError(
          code: 6000,
          message: 'disconnected',
        ),
      );
    } catch (_) {
      // A relay-sourced teardown error is non-fatal: the local session is
      // already cleared and the next connect re-pairs.
    }
  }

  /// Opens the wallet app to the pairing URI (mobile). Returns false when no
  /// URI is available yet or launching failed.
  @override
  Future<bool> launchPairingUri() async {
    final latest = await _pairingUris.stream.first;
    return launchUrl(
      Uri.parse(latest),
      mode: LaunchMode.externalApplication,
    );
  }
}