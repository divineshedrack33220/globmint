import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/models.dart';
import '../shared/services/api_client.dart';
import '../shared/services/auth_service.dart';
import '../shared/services/balance_service.dart';
import '../shared/services/bank_account_service.dart';
import '../shared/services/beneficiary_service.dart';
import '../shared/services/connectivity.dart';
import '../shared/services/conversion_service.dart';
import '../shared/services/events_service.dart';
import '../shared/services/savings_client.dart';
import '../shared/services/security_service.dart';
import '../shared/services/session_store.dart';
import '../shared/services/transaction_service.dart';
import '../shared/services/transfer_service.dart';
import '../shared/services/wallet_service.dart';

/// Shared online/offline signal fed by both the HTTP [ApiClient] and the SSE
/// [EventsServer]; drives the "no internet" banner.
final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

/// Secure persistence for the account session (Keychain/Keystore). The single
/// place the bearer token lives on device; [ApiClient] and [AuthService] share
/// it so there is never a second copy in plain preferences.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SecureSessionStore(),
);

/// Broadcasts "the server rejected our bearer token (401)" from [ApiClient]
/// to whichever services own the session. Kept as its own provider so
/// [apiClientProvider] and [authServiceProvider] never depend on each other
/// (which would be a provider cycle).
class UnauthorizedHandler {
  void Function()? _handler;

  void setHandler(void Function() handler) {
    _handler = handler;
  }

  void notify() => _handler?.call();
}

final unauthorizedHandlerProvider = Provider<UnauthorizedHandler>(
  (ref) => UnauthorizedHandler(),
);

/// Shared [ApiClient] used by every backend-backed service. Attaches the
/// bearer token from [sessionStoreProvider]; when the backend rejects it
/// (401) the [UnauthorizedHandler] is notified so the session can be cleared
/// and the user routed back to login.
final apiClientProvider = Provider<ApiClient>(
  (ref) {
    final client = ApiClient(
      connectivity: ref.watch(connectivityServiceProvider),
      sessionStore: ref.watch(sessionStoreProvider),
    );
    client.onUnauthorized = ref.watch(unauthorizedHandlerProvider).notify;
    return client;
  },
);

final authServiceProvider = Provider<AuthService>(
  (ref) {
    final auth = AuthService(
      ref.watch(apiClientProvider),
      sessionStore: ref.watch(sessionStoreProvider),
    );
    ref.watch(unauthorizedHandlerProvider).setHandler(
          () => auth.handleSessionExpired(),
        );
    return auth;
  },
);

final balanceServiceProvider = Provider<BalanceService>(
  (ref) => BalanceService(ref.watch(apiClientProvider)),
);

final transactionServiceProvider = Provider<TransactionService>(
  (ref) => TransactionService(ref.watch(apiClientProvider)),
);

final savingsClientProvider = Provider<SavingsClient>(
  (ref) => SavingsClient(ref.watch(apiClientProvider)),
);

final conversionServiceProvider = Provider<ConversionService>(
  (ref) => ConversionService(ref.watch(apiClientProvider)),
);

final transferServiceProvider = Provider<TransferService>(
  (ref) => TransferService(ref.watch(apiClientProvider)),
);

final beneficiaryServiceProvider = Provider<BeneficiaryService>(
  (ref) => BeneficiaryService(ref.watch(apiClientProvider)),
);

final bankAccountServiceProvider = Provider<BankAccountService>(
  (ref) => BankAccountService(ref.watch(apiClientProvider)),
);

final securityServiceProvider = Provider<SecurityService>(
  (ref) => SecurityService(ref.watch(apiClientProvider)),
);

/// Long-lived SSE client that pushes balance/vault/transaction changes to the
/// UI instead of the app polling every few seconds.
final eventsServerProvider = Provider<EventsServer>((ref) {
  final server = EventsServer(
    baseUrl: ref.watch(apiClientProvider).baseUrl,
    connectivity: ref.watch(connectivityServiceProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
  server.connect();
  ref.onDispose(server.close);
  return server;
});

/// Stream of pushed change notifications (see [EventsServer.stream]).
final eventsStreamProvider = StreamProvider<UserEvent>(
  (ref) => ref.watch(eventsServerProvider).stream,
);

/// Async providers used by pages to render live data.

final currentUserProvider = FutureProvider<User>((ref) async {
  final auth = ref.watch(authServiceProvider);
  final cached = auth.currentUser;
  if (cached != null) return cached;
  final me = await auth.me();
  if (me == null) throw ApiException(401, 'Not authenticated');
  return me;
});

final accountSummaryProvider = FutureProvider<AccountSummary>((ref) async {
  return ref.watch(balanceServiceProvider).getAccountSummary();
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  return ref.watch(transactionServiceProvider).getTransactions();
});

final recentTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final list = await ref.watch(transactionsProvider.future);
  final limit = 5;
  return list.length <= limit ? list : list.sublist(0, limit);
});

final beneficiariesProvider = FutureProvider<List<Beneficiary>>((ref) async {
  return ref.watch(beneficiaryServiceProvider).getBeneficiaries();
});

final bankAccountsProvider = FutureProvider<List<BankAccount>>((ref) async {
  return ref.watch(bankAccountServiceProvider).getAccounts();
});

final depositInfoProvider = FutureProvider<DepositInfo>((ref) async {
  return ref.watch(savingsClientProvider).getDepositInfo();
});

final vaultStatusProvider = FutureProvider<VaultStatus>((ref) async {
  return ref.watch(savingsClientProvider).getVaultStatus();
});

/// Pending time-locked withdrawals awaiting their release window. Refresh
/// after requesting, cancelling, or sweeping an elevation.
final pendingElevationsProvider = FutureProvider<List<PendingElevation>>((
  ref,
) async {
  return ref.watch(savingsClientProvider).listPendingElevations();
});

/// The user's clone recovery state (designated recovery address, armed delay,
/// in-flight window). Refreshed after designating or canceling a recovery.
final vaultRecoveryProvider = FutureProvider<RecoveryStatus>((ref) async {
  return ref.watch(savingsClientProvider).getRecoveryStatus();
});

/// Who controls the user's clone owner seat (the user's wallet vs the platform
/// placeholder signer). Refreshed after a custody claim.
final custodyProvider = FutureProvider<CustodyStatus>((ref) async {
  return ref.watch(savingsClientProvider).getCustodyStatus();
});

final devicesProvider = FutureProvider<List<Device>>((ref) async {
  return ref.watch(securityServiceProvider).getDevices();
});

final securityEventsProvider = FutureProvider<List<SecurityEvent>>((ref) async {
  return ref.watch(securityServiceProvider).getSecurityEvents();
});

final notificationsProvider =
    FutureProvider<({List<AppNotification> items, int unread})>((ref) async {
      return ref.watch(securityServiceProvider).getNotifications();
    });

/// Providers that expose mutable helpers/repositories for invalidation.
final transactionRepoProvider = Provider<TransactionService>(
  (ref) => ref.watch(transactionServiceProvider),
);

/// The signing backends used for EIP-712 withdrawals and recovery changes:
/// the injected browser wallet (MetaMask et al.) on web plus the WalletConnect
/// v2 dapp backend. Long-lived: pages connect/sign through it and watch
/// [walletProvider].
final walletServiceProvider = Provider<WalletService>(
  (ref) => WalletService(),
);

/// Live wallet connection state {address, chainId, status, signing, hasWallet}.
/// Pages watch this to render the connect/sign affordances and to gate the
/// self-custody (wallet-signed) path on the connected owner.
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(ref.watch(walletServiceProvider)),
);

/// Imperative interface over [WalletService], keeping UI state (signing flag,
/// last error, availability) in sync with the service's stream. Backend
/// selection happens here via [WalletService.defaultBackend]/[availableBackends]:
/// an already-connected backend is kept, a browser with an injected wallet
/// defaults to it, and everything else falls back to WalletConnect.
class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier(this._service) : super(WalletState.initial().copyWith(
            hasWallet: _service.hasWallet,
          )) {
    _sub = _service.stateStream.listen((connection) {
      state = WalletState(
        status: connection.status,
        address: connection.address,
        chainId: connection.chainId,
        expectedChainId: connection.expectedChainId,
        hasWallet: _service.hasWallet,
      );
    });
  }

  final WalletService _service;
  late final StreamSubscription<WalletConnectionState> _sub;

  /// Every backend usable on this platform/build (drives the chooser when both
  /// a browser wallet and WalletConnect are available).
  List<WalletBackend> get availableBackends => _service.availableBackends;

  /// The backend a connect would use when none is pinned: the connected
  /// backend while it stays available, else the browser wallet on web, else
  /// WalletConnect.
  WalletBackend? get defaultBackend => _service.defaultBackend;

  /// The backend the current connection belongs to, or null.
  WalletBackend? get activeBackend => _service.activeBackend;

  /// Connects a wallet, optionally pinned to [expectedChainId] and via a
  /// specific [backend] (from [availableBackends]). On a wrong chain the state
  /// becomes [WalletConnectionStatus.wrongChain] and the typed exception
  /// propagates so the caller can offer to switch.
  Future<void> connect({int? expectedChainId, WalletBackend? backend}) async {
    state = state.copyWith(error: null);
    try {
      await _service.connect(expectedChainId: expectedChainId, backend: backend);
    } on WalletUnavailableException catch (e) {
      state = state.copyWith(error: e.message);
      rethrow;
    } on WalletConnectionException catch (e) {
      state = state.copyWith(error: e.message);
      rethrow;
    } on WalletWrongChainException catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      rethrow;
    }
  }

  /// Asks the wallet to switch to [expectedChainId], then re-verifies.
  Future<void> ensureChain(int expectedChainId) async {
    state = state.copyWith(error: null);
    try {
      await _service.ensureChain(expectedChainId);
    } on WalletWrongChainException catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> disconnect() => _service.disconnect();

  /// Signs [typedData]; sets the transient [WalletState.signing] flag so the UI
  /// shows an in-progress indicator that a mid-flight disconnect clears via the
  /// connection stream. Malformed payloads surface as a typed [ApiException].
  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    state = state.copyWith(signing: true, error: null);
    try {
      final signature = await _service.signTypedData(typedData);
      state = state.copyWith(signing: false, error: null);
      return signature;
    } on ApiException catch (e) {
      state = state.copyWith(signing: false, error: e.message);
      rethrow;
    } on WalletSignatureException catch (e) {
      state = state.copyWith(signing: false, error: e.message);
      rethrow;
    } on WalletWrongChainException catch (e) {
      state = state.copyWith(signing: false, error: e.toString());
      rethrow;
    } on WalletConnectionException catch (e) {
      state = state.copyWith(signing: false, error: e.message);
      rethrow;
    } on WalletUnavailableException catch (e) {
      state = state.copyWith(signing: false, error: e.message);
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
