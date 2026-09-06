import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/models.dart';
import '../shared/services/api_client.dart';
import '../shared/services/auth_service.dart';
import '../shared/services/balance_service.dart';
import '../shared/services/bank_account_service.dart';
import '../shared/services/beneficiary_service.dart';
import '../shared/services/conversion_service.dart';
import '../shared/services/events_service.dart';
import '../shared/services/savings_client.dart';
import '../shared/services/security_service.dart';
import '../shared/services/transaction_service.dart';
import '../shared/services/transfer_service.dart';

/// Shared [ApiClient] used by every backend-backed service.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(apiClientProvider)));

final balanceServiceProvider =
    Provider<BalanceService>((ref) => BalanceService(ref.watch(apiClientProvider)));

final transactionServiceProvider =
    Provider<TransactionService>((ref) => TransactionService(ref.watch(apiClientProvider)));

final savingsClientProvider =
    Provider<SavingsClient>((ref) => SavingsClient(ref.watch(apiClientProvider)));

final conversionServiceProvider =
    Provider<ConversionService>((ref) => ConversionService(ref.watch(apiClientProvider)));

final transferServiceProvider =
    Provider<TransferService>((ref) => TransferService(ref.watch(apiClientProvider)));

final beneficiaryServiceProvider =
    Provider<BeneficiaryService>((ref) => BeneficiaryService(ref.watch(apiClientProvider)));

final bankAccountServiceProvider =
    Provider<BankAccountService>((ref) => BankAccountService(ref.watch(apiClientProvider)));

final securityServiceProvider =
    Provider<SecurityService>((ref) => SecurityService(ref.watch(apiClientProvider)));

/// Long-lived SSE client that pushes balance/vault/transaction changes to the
/// UI instead of the app polling every few seconds.
final eventsServerProvider = Provider<EventsServer>((ref) {
  final server = EventsServer(baseUrl: ref.watch(apiClientProvider).baseUrl);
  server.connect();
  ref.onDispose(server.close);
  return server;
});

/// Stream of pushed change notifications (see [EventsServer.stream]).
final eventsStreamProvider =
    StreamProvider<UserEvent>((ref) => ref.watch(eventsServerProvider).stream);


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

final recentTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
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
final pendingElevationsProvider =
    FutureProvider<List<PendingElevation>>((ref) async {
  return ref.watch(savingsClientProvider).listPendingElevations();
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
