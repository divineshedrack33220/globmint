import 'dart:async';
import 'dart:convert';

import 'api_client.dart';
import 'ethereum_provider.dart';
import 'wallet_connect_backend.dart';

/// Lifecycle of a connected wallet.
enum WalletConnectionStatus {
  /// No wallet is connected (the transient server/relay path is used).
  disconnected,

  /// A connection / account request is in flight.
  connecting,

  /// A wallet is connected on the expected chain.
  connected,

  /// A wallet is connected but on the wrong chain id.
  wrongChain,
}

/// A snapshot of the wallet connection, mirroring what a UI needs to render
/// the connect/sign affordances. [expectedChainId] is the chain the app asked
/// the wallet to use (0 when unknown/unconstrained).
class WalletConnectionState {
  const WalletConnectionState({
    required this.status,
    this.address,
    this.chainId,
    this.expectedChainId,
  });

  static const disconnected = WalletConnectionState(
    status: WalletConnectionStatus.disconnected,
  );

  final WalletConnectionStatus status;
  final String? address;
  final int? chainId;
  final int? expectedChainId;

  bool get isConnected => status == WalletConnectionStatus.connected;

  @override
  String toString() =>
      'WalletConnectionState(${status.name}, $address, chain=$chainId, '
      'expected=$expectedChainId)';
}

/// The UI-facing wallet state (used by `walletProvider`). Adds transient flags
/// the raw connection state does not carry: whether signing is in flight and
/// whether any backend is available on this platform.
class WalletState {
  const WalletState({
    required this.status,
    this.address,
    this.chainId,
    this.expectedChainId,
    this.signing = false,
    this.error,
    this.hasWallet = false,
  });

  factory WalletState.initial() => const WalletState(
        status: WalletConnectionStatus.disconnected,
      );

  final WalletConnectionStatus status;
  final String? address;
  final int? chainId;
  final int? expectedChainId;
  final bool signing;
  final String? error;

  /// True when at least one wallet backend is available on this build.
  final bool hasWallet;

  bool get isConnected => status == WalletConnectionStatus.connected;

  bool get isBusy => status == WalletConnectionStatus.connecting || signing;

  WalletState copyWith({
    WalletConnectionStatus? status,
    String? address,
    int? chainId,
    int? expectedChainId,
    bool? signing,
    String? error,
    bool? hasWallet,
  }) {
    return WalletState(
      status: status ?? this.status,
      address: address ?? this.address,
      chainId: chainId ?? this.chainId,
      expectedChainId: expectedChainId ?? this.expectedChainId,
      signing: signing ?? this.signing,
      error: error ?? this.error,
      hasWallet: hasWallet ?? this.hasWallet,
    );
  }
}

/// Thrown when no wallet backend is available on this platform/build.
class WalletUnavailableException implements Exception {
  const WalletUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when requesting accounts fails or the user cancels the prompt.
class WalletConnectionException implements Exception {
  const WalletConnectionException(this.message, {this.code = 'CONNECTION_FAILED'});
  final String message;
  final String code;

  @override
  String toString() => message;
}

/// Thrown when the connected wallet is on the wrong network. The service has
/// already recorded a [WalletConnectionStatus.wrongChain] state so the UI can
/// offer to switch chains ([WalletService.ensureChain]).
class WalletWrongChainException implements Exception {
  const WalletWrongChainException({required this.expectedChainId, required this.actualChainId});
  final int expectedChainId;
  final int actualChainId;

  @override
  String toString() =>
      'Wrong network: connected to chain $actualChainId, expected $expectedChainId.';
}

/// Thrown when the wallet refuses to sign or returns an unusable signature.
class WalletSignatureException implements Exception {
  const WalletSignatureException(this.message, {this.code = 'SIGNATURE_REJECTED'});
  final String message;
  final String code;

  @override
  String toString() => message;
}

/// A backend-side connection change the [WalletService] relays into its state
/// stream — the wallet switched account/chain remotely, or the WalletConnect
/// session expired/closed without the app asking for it.
enum WalletConnectionEventType {
  sessionExpired,
  accountChanged,
  chainChanged,
}

/// Carries a backend notification into the [WalletService] state machine.
class WalletConnectionEvent {
  const WalletConnectionEvent({required this.type, this.address, this.chainId});

  final WalletConnectionEventType type;
  final String? address;
  final int? chainId;
}

/// Optional capability a [WalletBackend] may expose: a stream of
/// externally-driven connection changes and an explicit session teardown.
/// The WalletConnect backend implements it; the injected browser wallet is
/// bridged synchronously per call so it never needs it.
abstract interface class WalletSessionEventsSource {
  Stream<WalletConnectionEvent> get events;
  Future<void> disconnectSession();
}

/// A pluggable signing backend. The app ships an injected-provider backend
/// (MetaMask and other EIP-1193 wallets on web). WalletConnect v2 is a second
/// backend that reports unavailable until the `reown_walletkit` package is
/// added and configured (project id, deep links, platform manifests); nothing
/// in [WalletService] depends on <em>which</em> backend signs, so it is a
/// drop-in.
abstract class WalletBackend {
  /// Human-readable backend name for UI labels ("MetaMask", "WalletConnect").
  String get name;

  /// Whether this backend is usable on the current platform/build.
  bool isAvailable();

  /// Opens the wallet's connect flow and returns authorized accounts.
  Future<List<String>> requestAccounts();

  /// Currently authorized accounts without prompting.
  Future<List<String>> accounts();

  /// The connected chain id. 0 when unknown or unreachable.
  Future<int> chainId();

  /// Requests the wallet to switch to [chainId] (EIP-3326). Throws when the
  /// wallet refuses or does not know the network.
  Future<void> switchChain(int chainId);

  /// Signs an EIP-712 typed-data payload with the first account's key.
  /// [typedDataJson] is the JSON string for `eth_signTypedData_v4`.
  Future<String> signTypedDataV4(String from, String typedDataJson);
}

/// The web injected-provider backend (MetaMask et al.). Fuses to the existing
/// [EthereumProvider] bridge so signing continues to happen in the wallet.
class InjectedWalletBackend implements WalletBackend {
  const InjectedWalletBackend();

  @override
  String get name => 'MetaMask';

  @override
  bool isAvailable() => EthereumProvider.available;

  @override
  Future<List<String>> requestAccounts() =>
      EthereumProvider.instance.requestAccounts();

  @override
  Future<List<String>> accounts() => EthereumProvider.instance.accounts();

  @override
  Future<int> chainId() => EthereumProvider.instance.chainId();

  @override
  Future<void> switchChain(int chainId) =>
      EthereumProvider.instance.switchChain(chainId);

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) =>
      EthereumProvider.instance.signTypedDataV4Raw(from, typedDataJson);
}

/// The WalletConnect v2 backend lives in `wallet_connect_backend.dart`. It
/// implements the dapp role of the protocol (pairing URI → QR / deep link,
/// then `eth_signTypedData_v4` over the approved session) and additionally
/// implements [WalletSessionEventsSource] so wallet-driven session expiry and
/// account/chain changes flow into [WalletService.stateStream]. The UI and the
/// withdrawal/recovery flows only ever see [WalletBackend].

/// Backend selection order: injected provider first, WalletConnect next.
/// Not const: the WalletConnect backend holds stream controllers/event wiring
/// that is initialized per app run.
final defaultWalletBackends = <WalletBackend>[
  const InjectedWalletBackend(),
  WalletConnectWalletBackend(),
];

/// Signature-gated signing: the wallet object the rest of the client uses to
/// connect a wallet, verify the active chain, and produce the EIP-712
/// signatures the backend relays.
///
/// Only the user's wallet ever produces a signature — nothing here holds, logs,
/// or transmits a private key, and a signature is handed to the backend exactly
/// once by the calling flow. A mid-flight [disconnect] invalidates any pending
/// signature rather than returning it.
class WalletService {
  WalletService({List<WalletBackend>? backends})
      : _backends = backends ?? defaultWalletBackends {
    // Emit the initial state so late listeners still see a snapshot.
    _state = WalletConnectionState.disconnected;
  }

  final List<WalletBackend> _backends;
  final StreamController<WalletConnectionState> _stateCtrl =
      StreamController<WalletConnectionState>.broadcast(sync: true);
  WalletConnectionState _state = WalletConnectionState.disconnected;

  /// The backend a successful [connect] pinned to. Kept so a live WalletConnect
  /// session (or connected browser wallet) survives re-entry and is never
  /// silently replaced by another backend.
  WalletBackend? _activeBackend;
  StreamSubscription<WalletConnectionEvent>? _backendEventsSub;

  /// Broadcast stream of connection state changes.
  Stream<WalletConnectionState> get stateStream => _stateCtrl.stream;

  /// The latest known connection state.
  WalletConnectionState get current => _state;

  /// The backend current state belongs to, or null when disconnected.
  WalletBackend? get activeBackend => _activeBackend;

  /// Every backend usable on this platform/build. Drives the UI chooser (e.g.
  /// "MetaMask or WalletConnect" on a browser with an injected wallet).
  List<WalletBackend> get availableBackends =>
      _backends.where((b) => b.isAvailable()).toList();

  WalletBackend? get _backend {
    for (final b in _backends) {
      if (b.isAvailable()) return b;
    }
    return null;
  }

  /// The backend a connect should use unless the caller pins one: the
  /// already-connected backend while it is still available, else the injected
  /// browser wallet on web, else the WalletConnect backend.
  WalletBackend? get defaultBackend {
    final active = _activeBackend;
    if (active != null && active.isAvailable()) return active;
    for (final b in _backends) {
      if (b is InjectedWalletBackend && b.isAvailable()) return b;
    }
    return _backend;
  }

  /// The backend current account/chain/sign operations operate on.
  WalletBackend? get _operationalBackend => _activeBackend ?? _backend;

  /// True when at least one signing backend is available on this build.
  bool get hasWallet => _backend != null;

  void _emit(WalletConnectionState next) {
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  void _subscribeBackendEvents(WalletBackend backend) {
    if (backend is! WalletSessionEventsSource) return;
    if (_backendEventsSub != null) return;
    _backendEventsSub =
        (backend as WalletSessionEventsSource).events.listen(_onBackendEvent);
  }

  /// Relays wallet-driven changes (session expiry, account/chain switches)
  /// into the state stream so `walletProvider` and the UI react without a
  /// user action.
  void _onBackendEvent(WalletConnectionEvent event) {
    _emit(switch (event.type) {
      WalletConnectionEventType.sessionExpired => WalletConnectionState(
        status: WalletConnectionStatus.disconnected,
        expectedChainId: _state.expectedChainId,
      ),
      WalletConnectionEventType.accountChanged =>
        _accountChangedState(event),
      WalletConnectionEventType.chainChanged =>
        _chainChangedState(event),
    });
  }

  WalletConnectionState _accountChangedState(WalletConnectionEvent event) {
    final address = event.address;
    if (address == null || address.isEmpty) {
      return WalletConnectionState(
        status: WalletConnectionStatus.disconnected,
        expectedChainId: _state.expectedChainId,
      );
    }
    final chain = event.chainId ?? _state.chainId ?? 0;
    final expected = _state.expectedChainId ?? 0;
    return WalletConnectionState(
      status: (expected != 0 && chain != 0 && chain != expected)
          ? WalletConnectionStatus.wrongChain
          : WalletConnectionStatus.connected,
      address: address,
      chainId: chain,
      expectedChainId: expected == 0 ? null : expected,
    );
  }

  WalletConnectionState _chainChangedState(WalletConnectionEvent event) {
    final chain = event.chainId ?? 0;
    final expected = _state.expectedChainId ?? 0;
    return WalletConnectionState(
      status: (expected != 0 && chain != 0 && chain != expected)
          ? WalletConnectionStatus.wrongChain
          : WalletConnectionStatus.connected,
      address: _state.address,
      chainId: chain,
      expectedChainId: expected == 0 ? null : expected,
    );
  }

  /// Connects a wallet, optionally pinned to [expectedChainId]. When
  /// [backend] is given (e.g. chosen from [availableBackends]) that backend is
  /// used; otherwise [defaultBackend] picks the already-connected one, else
  /// the injected browser wallet on web, else WalletConnect. When the wallet
  /// is on a different network the state becomes
  /// [WalletConnectionStatus.wrongChain] and [WalletWrongChainException] is
  /// thrown so the UI can offer to switch.
  Future<WalletConnectionState> connect({
    int? expectedChainId,
    WalletBackend? backend,
  }) async {
    final effective = backend ?? defaultBackend;
    if (effective == null) {
      _emit(WalletConnectionState.disconnected);
      throw const WalletUnavailableException(
          'No wallet is available here. Use a browser with MetaMask installed.');
    }

    _emit(WalletConnectionState(
      status: WalletConnectionStatus.connecting,
      expectedChainId: expectedChainId,
    ));

    final List<String> accounts;
    try {
      accounts = await effective.requestAccounts();
    } catch (e) {
      _emit(WalletConnectionState.disconnected);
      if (e is WalletUnavailableException ||
          e is WalletConnectionException ||
          e is WalletSignatureException ||
          e is WalletWrongChainException ||
          e is ApiException) {
        rethrow;
      }
      throw WalletConnectionException(
        'You cancelled the connection request (${effective.name}).',
        code: 'USER_REJECTED',
      );
    }
    if (accounts.isEmpty) {
      _emit(WalletConnectionState.disconnected);
      throw const WalletConnectionException(
        'No account was returned by the wallet.',
      );
    }

    int chain = 0;
    try {
      chain = await effective.chainId();
    } catch (_) {
      // Chain unknown; treat as 0 so the wrong-chain guard only fires when
      // the wallet explicitly reports a different chain.
    }

    if (expectedChainId != null &&
        expectedChainId != 0 &&
        chain != 0 &&
        chain != expectedChainId) {
      _emit(WalletConnectionState(
        status: WalletConnectionStatus.wrongChain,
        address: accounts.first,
        chainId: chain,
        expectedChainId: expectedChainId,
      ));
      throw WalletWrongChainException(
        expectedChainId: expectedChainId,
        actualChainId: chain,
      );
    }

    _activeBackend = effective;
    _subscribeBackendEvents(effective);
    _emit(WalletConnectionState(
      status: WalletConnectionStatus.connected,
      address: accounts.first,
      chainId: chain,
      expectedChainId: expectedChainId,
    ));
    return _state;
  }

  /// Asks the connected wallet to switch to [expectedChainId]. On success the
  /// state becomes connected; otherwise it stays/becomes wrongChain and
  /// [WalletWrongChainException] is thrown. [WalletConnectionException]s with
  /// a stable code (e.g. `UNSUPPORTED_CHAIN`/`SESSION_EXPIRED`) pass through
  /// so callers can show the precise recovery copy.
  Future<WalletConnectionState> ensureChain(int expectedChainId) async {
    final backend = _operationalBackend;
    if (backend == null) throw const WalletUnavailableException('No wallet available.');
    if (_state.chainId == expectedChainId) return _state;
    try {
      await backend.switchChain(expectedChainId);
    } on WalletUnavailableException {
      rethrow;
    } on WalletConnectionException {
      rethrow;
    } on WalletWrongChainException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw WalletWrongChainException(
        expectedChainId: expectedChainId,
        actualChainId: _state.chainId ?? 0,
      );
    }
    final after = await backend.chainId();
    if (after == expectedChainId) {
      _emit(WalletConnectionState(
        status: WalletConnectionStatus.connected,
        address: _state.address,
        chainId: after,
        expectedChainId: expectedChainId,
      ));
      return _state;
    }
    _emit(WalletConnectionState(
      status: WalletConnectionStatus.wrongChain,
      address: _state.address,
      chainId: after,
      expectedChainId: expectedChainId,
    ));
    throw WalletWrongChainException(
      expectedChainId: expectedChainId,
      actualChainId: after,
    );
  }

  /// The first authorized account, or null when none.
  Future<String?> currentAddress() async {
    final backend = _operationalBackend;
    if (backend == null) return null;
    try {
      final accounts = await backend.accounts();
      return accounts.isNotEmpty ? accounts.first : null;
    } catch (_) {
      return null;
    }
  }

  /// Clears the connection and tear down the backend session (a live
  /// WalletConnect session is explicitly closed). Any in-flight signature is
  /// abandoned by the mid-flight guard in [signTypedData].
  Future<void> disconnect() async {
    final backend = _activeBackend;
    if (backend is WalletSessionEventsSource) {
      try {
        await (backend as WalletSessionEventsSource).disconnectSession();
      } catch (_) {
        // Local teardown failures are non-fatal; state clears regardless.
      }
    }
    _activeBackend = null;
    _emit(WalletConnectionState.disconnected);
  }

  /// Signs an EIP-712 typed-data payload (as built for `eth_signTypedData_v4`)
  /// with the connected account. The payload is validated before anything is
  /// offered to the wallet; a malformed payload throws a typed [ApiException]
  /// (code `INVALID_TYPED_DATA`) without touching the wallet.
  ///
  /// Throws [WalletSignatureException] when the user rejects (code
  /// `USER_REJECTED`), [WalletWrongChainException] when the active chain no
  /// longer matches the expected one, [WalletConnectionException] (code
  /// `SESSION_EXPIRED`) when the wallet disconnected mid-flight, and
  /// [ApiException] (code `WALLET_NOT_AVAILABLE`) when no WalletConnect project
  /// id was compiled in.
  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    _validateTypedData(typedData);

    final backend = _operationalBackend;
    if (backend == null) {
      throw const WalletUnavailableException(
          'No wallet is available to sign. Use a browser with MetaMask installed.');
    }

    final from = _state.isConnected
        ? _state.address
        : (await currentAddress());
    if (from == null || from.isEmpty) {
      throw const WalletConnectionException('Connect a wallet before signing.');
    }

    final expected = _state.expectedChainId ?? 0;
    if (expected != 0 && _state.chainId != null && _state.chainId != expected) {
      _emit(WalletConnectionState(
        status: WalletConnectionStatus.wrongChain,
        address: from,
        chainId: _state.chainId,
        expectedChainId: expected,
      ));
      throw WalletWrongChainException(
        expectedChainId: expected,
        actualChainId: _state.chainId ?? 0,
      );
    }

    final String signature;
    try {
      signature = await backend.signTypedDataV4(from, jsonEncode(typedData));
    } on WalletWrongChainException {
      rethrow;
    } on WalletSignatureException {
      rethrow;
    } on WalletConnectionException {
      rethrow;
    } on WalletUnavailableException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw WalletSignatureException(
        'The wallet did not approve the signature.',
        code: 'USER_REJECTED',
      );
    }

    // Mid-flight disconnect (account changed / cleared while signing): never
    // return a signature the UI no longer owns a connection near.
    if (!_state.isConnected || _state.address != from) {
      throw const WalletConnectionException(
          'Your wallet disconnected while signing — please try again.');
    }
    return signature;
  }

  /// Structural validation that the payload is a usable signable object.
  /// Mirrors the shape the contract/backend expects (domain + message +
  /// primaryType + types); anything else is a programming error surfaced as a
  /// typed API error instead of a confusing wallet panic.
  void _validateTypedData(Map<String, dynamic> typedData) {
    if (typedData['types'] is! Map) {
      throw ApiException(400, 'The signature request is malformed (types).',
          code: 'INVALID_TYPED_DATA');
    }
    final primaryType = typedData['primaryType'];
    if (primaryType is! String || primaryType.isEmpty) {
      throw ApiException(400, 'The signature request is malformed (primaryType).',
          code: 'INVALID_TYPED_DATA');
    }
    final domain = typedData['domain'];
    if (domain is! Map ||
        domain['verifyingContract'] is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(domain['verifyingContract'] as String)) {
      throw ApiException(400, 'The signature request is malformed (domain).',
          code: 'INVALID_TYPED_DATA');
    }
    final message = typedData['message'];
    if (message is! Map || message.isEmpty) {
      throw ApiException(400, 'The signature request is malformed (message).',
          code: 'INVALID_TYPED_DATA');
    }
  }
}