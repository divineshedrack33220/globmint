import '../../core/constants/app_constants.dart';
import '../../core/enums/transaction_status.dart';
import '../../core/enums/transaction_type.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed transaction service. Maps `/api/v1/transactions` (snake_case,
/// major-unit decimal strings) into the frontend [Transaction] model.
class TransactionService {
  TransactionService(this._api);

  final ApiClient _api;

  Future<List<Transaction>> getTransactions() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/transactions');
    final list = ((data?['transactions'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return list.map(_fromApi).toList();
  }

  Future<List<Transaction>> getRecentTransactions({int limit = 5}) async {
    final all = await getTransactions();
    if (all.length <= limit) return all;
    return all.sublist(0, limit);
  }

  Future<Transaction?> getTransaction(String id) async {
    final all = await getTransactions();
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  Transaction _fromApi(Map<String, dynamic> j) {
    final type = _typeFrom(j['type'] as String? ?? '');
    final currency = (j['currency'] as String? ?? 'NGN').toUpperCase();
    final amount = double.tryParse(j['amount'] as String? ?? '0') ?? 0;

    final isReverse = _isReverse(type, currency);
    final displayAmount = isReverse ? amount : amount;

    return Transaction(
      id: j['id'] as String? ?? '',
      type: type,
      amount: displayAmount,
      currency: currency,
      status: _statusFrom(j['status'] as String? ?? ''),
      date: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      reference: j['reference'] as String?,
      fee: double.tryParse(j['fee'] as String? ?? ''),
      exchangeRate: double.tryParse(j['exchange_rate'] as String? ?? ''),
      destination: _destination(type, currency, j),
      fromCurrency: currency,
      toCurrency: currency,
      description: j['narration'] as String?,
    );
  }

  String? _destination(TransactionType type, String currency, Map<String, dynamic> j) {
    switch (type) {
      case TransactionType.deposit:
        return 'Globmint Available';
      case TransactionType.savings:
        return 'Globmint Savings (USDT)';
      case TransactionType.withdrawal:
        return (j['destination'] as String?) ?? 'Bank';
      case TransactionType.transfer:
        return (j['destination'] as String?) ?? 'Beneficiary';
      case TransactionType.conversion:
        return currency;
    }
  }

  TransactionType _typeFrom(String raw) {
    switch (raw.toLowerCase()) {
      case 'deposit':
        return TransactionType.deposit;
      case 'withdrawal':
        return TransactionType.withdrawal;
      case 'conversion':
        return TransactionType.conversion;
      case 'transfer':
        return TransactionType.transfer;
      case 'savings':
        return TransactionType.savings;
      default:
        return TransactionType.transfer;
    }
  }

  TransactionStatus _statusFrom(String raw) {
    switch (raw.toLowerCase()) {
      case 'initiated':
        return TransactionStatus.initiated;
      case 'processing':
        return TransactionStatus.processing;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      case 'reversed':
        return TransactionStatus.reversed;
      default:
        return TransactionStatus.completed;
    }
  }

  bool _isReverse(TransactionType type, String currency) {
    // A conversion into NGN is a debit from the user's perspective.
    return type == TransactionType.conversion && currency == 'NGN';
  }
}
