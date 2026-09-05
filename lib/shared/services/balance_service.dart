import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed balance service. Maps the `/api/v1/balances` response into
/// the frontend [AccountSummary] model.
class BalanceService {
  BalanceService(this._api);

  final ApiClient _api;

  /// Fetches the authenticated user's account balances and derives an
  /// [AccountSummary]. The savings figure is driven by the on-chain vault
  /// USDC holdings so it stays consistent everywhere in the app; the exchange
  /// rate snapshot falls back to the current market rate placeholder.
  Future<AccountSummary> getAccountSummary() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/balances');
    final list = ((data?['balances'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    Account? available;
    Account? fallback;
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
      if (!kind.contains('sav') && currency != AppConstants.savingsCurrency) {
        fallback ??= Account(id: id, currency: currency, balance: balance);
        // Prefer the NGN available wallet; the API contract lists NGN first,
        // but we must not rely on ordering.
        if (currency == 'NGN') {
          available = Account(id: id, currency: currency, balance: balance);
          break;
        }
      }
    }
    available ??= fallback ?? Account(id: '', currency: 'NGN', balance: 0);

    final currentRate = _defaultRate();
    final vaultUsdc = await _vaultUsdcBalance();

    final savings =
        Account(id: '', currency: AppConstants.savingsCurrency, balance: vaultUsdc);

    return AccountSummary(
      savings: savings,
      available: available,
      totalNgnEquivalent: available.balance,
      totalUsdtEquivalent: vaultUsdc,
      currentRate: currentRate,
    );
  }

  /// Reads the on-chain vault USDC holdings from the vault-status endpoint and
  /// returns the numeric part; `0` when unavailable or errored.
  Future<double> _vaultUsdcBalance() async {
    try {
      final status = await _api.get('${AppConstants.apiV1Prefix}/savings/vault-status');
      final raw = status?['vault_usdc_balance'] as String? ?? '';
      final match = RegExp(r'^\s*([\d.]+)').firstMatch(raw);
      if (match == null || match.group(1) == null) return 0;
      return double.tryParse(match.group(1)!) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  double _defaultRate() => 1604.50;
}