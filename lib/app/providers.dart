import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/models.dart';
import '../shared/services/api_client.dart';
import '../shared/services/app_lock_service.dart';
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
  final List<void Function()> _handlers = [];

  void add(void Function() handler) => _handlers.add(handler);

  void remove(void Function() handler) => _handlers.remove(handler);

  void notify() {
    for (final handler in List.of(_handlers)) {
      handler();
    }
  }
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
    ref.watch(unauthorizedHandlerProvider).add(
          () => auth.handleSessionExpired(),
        );
    return auth;
  },
);

/// Biometric/device-PIN helper; abstracted so the unlock flow can be unit
/// tested without a real [LocalAuthentication] plugin.
final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(),
);

/// Notifier driving the app-lock gate: starting → locked → unlocking →
/// unlocked, with an extra [AppLockState.needsLogin] flag for the gate to
/// route to `/login` when the session was missing or expired.
final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>(
  (ref) => AppLockNotifier(
    service: ref.watch(appLockServiceProvider),
    auth: ref.watch(authServiceProvider),
    store: ref.watch(sessionStoreProvider),
  ),
);

/// State of the biometric / password lock gate.
class AppLockState {
  const AppLockState({
    this.status = AppLockStatus.starting,
    this.biometricsAvailable = false,
    this.failedAttempts = 0,
    this.needsLogin = false,
    this.sessionExists = false,
  });

  final AppLockStatus status;
  final bool biometricsAvailable;
  final int failedAttempts;

  /// True when a stored (and possibly still valid) session was present at
  /// startup. Lets the gate distinguish "opened with no session" (stay on
  /// the landing page) from "unlocked a session" (land on /home).
  final bool sessionExists;

  /// True when the gate should navigate to `/login` instead of unlocking the
  /// app (the session was invalid, or the user chose "Use password instead").
  final bool needsLogin;

  /// Whether the biometric button must be hidden — either the device has no
  /// biometrics or 3 consecutive failures forced a password fallback.
  bool get passwordFallbackRequired => !biometricsAvailable || failedAttempts >= 3;

  AppLockState copyWith({
    AppLockStatus? status,
    bool? biometricsAvailable,
    int? failedAttempts,
    bool? needsLogin,
    bool? sessionExists,
  }) =>
      AppLockState(
        status: status ?? this.status,
        biometricsAvailable: biometricsAvailable ?? this.biometricsAvailable,
        failedAttempts: failedAttempts ?? this.failedAttempts,
        needsLogin: needsLogin ?? this.needsLogin,
        sessionExists: sessionExists ?? this.sessionExists,
      );
}

enum AppLockStatus { starting, locked, unlocking, unlocked }

/// State machine backing [appLockProvider].
class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier({
    required this._service,
    required this._auth,
    required this._store,
  }) : super(const AppLockState()) {
    _initialize();
  }

  final AppLockService _service;
  final AuthService _auth;
  final SessionStore _store;

  bool _autoPromptDone = false;

  /// Reads the stored token, validates it against the backend, checks
  /// biometric capability, and transitions to the initial gate state.
  Future<void> _initialize() async {
    final token = await _store.readToken();
    var biometrics = false;
    try {
      biometrics = await _service.isBiometricAvailable();
    } catch (_) {
      biometrics = false;
    }

    if (token == null || token.isEmpty) {
      // Nothing to gate: app starts normally (welcome / login).
      state = const AppLockState(status: AppLockStatus.unlocked);
      return;
    }

    // A token exists: validate it before unlocking anything.
    try {
      final user = await _auth.currentSession();
      if (user == null) {
        // Token was 401'd (currentSession clears it) or otherwise empty.
        state = AppLockState(
          status: AppLockStatus.unlocked,
          biometricsAvailable: biometrics,
          needsLogin: true,
        );
        return;
      }
    } on ApiException catch (e) {
      // Non-401 failure: network down, 5xx, etc. Do NOT trust the session
      // without confirmation — require biometric / password.
      debugPrint('AppLock: session validation failed (${e.statusCode}): ${e.message}');
    } catch (e) {
      debugPrint('AppLock: unexpected session validation error: $e');
    }

    // A (possibly invalid) token is present. Require confirmation before
    // showing any data. sessionExists is only useful as a gate flag once the
    // user actually unlocks, so it stays true regardless of validation result.
    state = AppLockState(
      status: AppLockStatus.locked,
      biometricsAvailable: biometrics,
      sessionExists: true,
    );
    _maybeAutoPrompt(biometrics);
  }

  /// On cold start, automatically show the biometric prompt when the device
  /// supports it — this is the "fast reopen" the user expects.
  Future<void> _maybeAutoPrompt(bool biometrics) async {
    if (!biometrics || _autoPromptDone) return;
    _autoPromptDone = true;
    // Brief yield so the initial frame (lock screen) renders before the
    // system dialog overlays it.
    await Future<void>.delayed(Duration.zero);
    await unlockWithBiometric();
  }

  /// Prompts the OS for biometrics (or device-PIN fallback). Succeeding
  /// transitions the gate to [AppLockStatus.unlocked]; failing increments
  /// the counter and after 3 attempts disables the biometric button.
  Future<void> unlockWithBiometric() async {
    if (state.status == AppLockStatus.unlocking ||
        state.status == AppLockStatus.unlocked) {
      return;
    }
    state = state.copyWith(status: AppLockStatus.unlocking);
    final ok = await _service.authenticate(
      reason: 'Unlock GlobMint to view your balance',
    );
    // Guard: the state may have changed (relock, expiry) while the prompt
    // was on-screen.
    if (state.status != AppLockStatus.unlocking) return;
    if (ok) {
      state = state.copyWith(status: AppLockStatus.unlocked);
    } else {
      final attempts = state.failedAttempts + 1;
      state = state.copyWith(
        status: AppLockStatus.locked,
        failedAttempts: attempts,
        // After 3 consecutive failures, hide the biometric button.
        biometricsAvailable: attempts >= 3 ? false : state.biometricsAvailable,
      );
    }
  }

  /// The user tapped "Use password instead". The gate should unlock so the
  /// login page can be shown, and route the user there.
  void signalPasswordFallback() {
    state = state.copyWith(
      status: AppLockStatus.unlocked,
      needsLogin: true,
    );
  }

  /// Clears the `needsLogin` flag once the gate has navigated to `/login`.
  void clearNeedsLogin() {
    if (state.needsLogin) state = state.copyWith(needsLogin: false);
  }

  /// Called from the gate to cover the app again when backgrounded. Re-arms
  /// the auto-prompt so the next `unlockWithBiometric` isn't required to be
  /// triggered manually (the prompt reappears on the next resume).
  void relock() {
    state = AppLockState(
      status: AppLockStatus.locked,
      biometricsAvailable: state.biometricsAvailable,
      sessionExists: true,
    );
    _autoPromptDone = false; // allow auto-prompt on next re-lock
    _maybeAutoPrompt(state.biometricsAvailable);
  }

  /// Called by [UnauthorizedHandler] when the backend rejects the bearer
  /// token mid-session (401): unlock so the gate can route to `/login`.
  void expireToLogin() {
    state = AppLockState(
      status: AppLockStatus.unlocked,
      biometricsAvailable: state.biometricsAvailable,
      needsLogin: true,
    );
  }
}

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
