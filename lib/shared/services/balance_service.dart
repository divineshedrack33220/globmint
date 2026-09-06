import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed balance service. Maps the `/api/v1/balances` response into
/// the frontend [AccountSummary] model.
class BalanceService {
  BalanceService(this._api);

  final ApiClient _api;

  /// Fetches the authenticated user's account balances and derives an
  /// [AccountSummary]. All figures are personal ledger balances for this user:
  /// the shared on-chain vault pool is never merged into anyone's totals (it
  /// is shown only as labelled on-chain info where relevant).
  Future<AccountSummary> getAccountSummary() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/balances');
    final list = ((data?['balances'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    Account? available;
    Account? fallback;
    Account? savings;
    for (final raw in list) {
      final id = raw['account_id'] as String? ?? '';
      final currency = (raw['currency'] as String? ?? 'NGN').toUpperCase();
      final amountMinor = (raw['amount_minor'] as num?)?.toDouble() ?? 0;
      final rawAmount = raw['amount'];
      final double amountMajor =
          rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse('$rawAmount') ?? amountMinor / 100;
      final balance = amountMajor > 0 ? amountMajor : amountMinor / 100;

      final kind = (raw['kind'] as String? ?? '').toLowerCase();
      if (kind.contains('sav')) {
        // The user's own savings wallet (ledger). Never replaced with the
        // shared on-chain pool: personal totals must mirror personal funds.
        savings ??= Account(id: id, currency: currency, balance: balance);
        continue;
      }
      if (currency != AppConstants.savingsCurrency) {
        fallback ??= Account(id: id, currency: currency, balance: balance);
        // Prefer the NGN available wallet; the API contract lists NGN first,
        // but we must not rely on ordering.
        if (currency == 'NGN') {
          available ??= Account(id: id, currency: currency, balance: balance);
        }
      }
    }
    available ??= fallback ?? Account(id: '', currency: 'NGN', balance: 0);
    savings ??= Account(id: '', currency: 'NGN', balance: 0);

    final currentRate = await _liveRate();
    final totalNgn = available.balance + savings.balance;

    return AccountSummary(
      savings: savings,
      available: available,
      totalNgnEquivalent: totalNgn,
      totalUsdtEquivalent: currentRate > 0 ? totalNgn / currentRate : 0,
      currentRate: currentRate,
    );
  }

  /// Live NGN-per-USDC rate from the server book (market feed when reachable,
  /// seeded otherwise). Falls back to the last-known default when offline.
  Future<double> _liveRate() async {
    try {
      final data = await _api
          .get('${AppConstants.apiV1Prefix}/money/rate?from=USDC&to=NGN');
      final minor = (data?['rate_minor'] as num?)?.toDouble() ?? 0;
      if (minor > 0) return minor / 100;
    } catch (_) {}
    return _defaultRate();
  }

  double _defaultRate() => 1604.50;
}