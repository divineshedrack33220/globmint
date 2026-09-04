import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed balance service. Maps the `/api/v1/balances` response into
/// the frontend [AccountSummary] model.
class BalanceService {
  BalanceService(this._api);

  final ApiClient _api;

  /// Fetches the authenticated user's account balances and derives an
  /// [AccountSummary]. When the exchange-rate snapshot is not part of the
  /// response, the USD equivalent is exposed only if the backend provides it.
  Future<AccountSummary> getAccountSummary() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/balances');
    final list = ((data?['balances'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (list.isEmpty) {
      return _emptySummary();
    }

    Account? available;
    Account? savings;
    for (final raw in list) {
      final id = raw['account_id'] as String? ?? '';
      final currency = (raw['currency'] as String? ?? 'NGN').toUpperCase();
      final amountMinor = (raw['amount_minor'] as num?)?.toDouble() ?? 0;
      final amountMajor = (raw['amount'] as num?)?.toDouble() ?? amountMinor / 100;
      final balance = amountMajor > 0 ? amountMajor : amountMinor / 100;

      final kind = (raw['kind'] as String? ?? '').toLowerCase();
      final acc = Account(
        id: id,
        currency: currency,
        balance: balance,
      );
      if (kind.contains('sav') || currency == AppConstants.savingsCurrency) {
        savings ??= acc;
      } else {
        available ??= acc;
      }
    }

    available ??= Account(id: '', currency: 'NGN', balance: 0);
    savings ??= Account(id: '', currency: AppConstants.savingsCurrency, balance: 0);

    // Without a live rate, USDT equivalent equals the USDT balance and the
    // NGN equivalent is the available-NGN balance; the displayed rate falls
    // back to the current market rate placeholder.
    final currentRate = _defaultRate();
    final totalNgn = available.balance;
    final totalUsdt = savings.balance;

    return AccountSummary(
      savings: savings,
      available: available,
      totalNgnEquivalent: totalNgn,
      totalUsdtEquivalent: totalUsdt,
      currentRate: currentRate,
    );
  }

  AccountSummary _emptySummary() => AccountSummary(
        savings: Account(id: '', currency: AppConstants.savingsCurrency, balance: 0),
        available: Account(id: '', currency: AppConstants.defaultCurrency, balance: 0),
        totalNgnEquivalent: 0,
        totalUsdtEquivalent: 0,
        currentRate: _defaultRate(),
      );

  double _defaultRate() => 1604.50;
}