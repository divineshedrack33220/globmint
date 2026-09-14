import 'dart:async';
import 'dart:convert';

import 'api_client.dart';
import 'ethereum_provider.dart';

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

/// The WalletConnect v2 seam. It deliberately reports unavailable so [WalletService]
/// falls back to the injected backend; when `reown_walletkit` is wired in, its
/// [isAvailable] flips on and every method delegates to the session. The UI and
/// the rest of the withdrawal/recovery flows never change.
class WalletConnectWalletBackend implements WalletBackend {
  const WalletConnectWalletBackend();

  @override
  String get name => 'WalletConnect';

  @override
  bool isAvailable() => false;

  @override
  Future<List<String>> requestAccounts() => throw const WalletUnavailableException(
      'WalletConnect v2 is not enabled in this build yet.');

  @override
  Future<List<String>> accounts() => throw const WalletUnavailableException(
      'WalletConnect v2 is not enabled in this build yet.');

  @override
  Future<int> chainId() =>
      throw const WalletUnavailableException('WalletConnect v2 is not enabled in this build yet.');

  @override
  Future<void> switchChain(int chainId) => throw const WalletUnavailableException(
      'WalletConnect v2 is not enabled in this build yet.');

  @override
  Future<String> signTypedDataV4(String from, String typedDataJson) =>
      throw const WalletUnavailableException(
          'WalletConnect v2 is not enabled in this build yet.');
}

/// Backend selection order: injected provider first, WalletConnect next.
const defaultWalletBackends = <WalletBackend>[
  InjectedWalletBackend(),
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

  /// Broadcast stream of connection state changes.
  Stream<WalletConnectionState> get stateStream => _stateCtrl.stream;

  /// The latest known connection state.
  WalletConnectionState get current => _state;

  WalletBackend? get _backend {
    for (final b in _backends) {
      if (b.isAvailable()) return b;
    }
    return null;
  }

  /// True when at least one signing backend is available on this build.
  bool get hasWallet => _backend != null;

  void _emit(WalletConnectionState next) {
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  /// Connects a wallet. When [expectedChainId] is supplied and the wallet is on
  /// another network, the state becomes [WalletConnectionStatus.wrongChain] and
  /// [WalletWrongChainException] is thrown so the UI can offer to switch.
  Future<WalletConnectionState> connect({int? expectedChainId}) async {
    final backend = _backend;
    if (backend == null) {
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
      accounts = await backend.requestAccounts();
    } catch (e) {
      _emit(WalletConnectionState.disconnected);
      throw WalletConnectionException(
        'You cancelled the connection request (${backend.name}).',
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
      chain = await backend.chainId();
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
  /// [WalletWrongChainException] is thrown.
  Future<WalletConnectionState> ensureChain(int expectedChainId) async {
    final backend = _backend;
    if (backend == null) throw const WalletUnavailableException('No wallet available.');
    if (_state.chainId == expectedChainId) return _state;
    try {
      await backend.switchChain(expectedChainId);
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
    final backend = _backend;
    if (backend == null) return null;
    try {
      final accounts = await backend.accounts();
      return accounts.isNotEmpty ? accounts.first : null;
    } catch (_) {
      return null;
    }
  }

  /// Clears the connection. Any in-flight signature is abandoned by the
  /// mid-flight guard in [signTypedData].
  Future<void> disconnect() async {
    _emit(WalletConnectionState.disconnected);
  }

  /// Signs an EIP-712 typed-data payload (as built for `eth_signTypedData_v4`)
  /// with the connected account. The payload is validated before anything is
  /// offered to the wallet; a malformed payload throws a typed [ApiException]
  /// (code `INVALID_TYPED_DATA`) without touching the wallet.
  ///
  /// Throws [WalletSignatureException] when the user rejects, [WalletWrongChainException]
  /// when the active chain no longer matches the expected one, and
  /// [WalletConnectionException] when the wallet disconnected mid-flight.
  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    _validateTypedData(typedData);

    final backend = _backend;
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