import '../../core/constants/app_constants.dart';
import '../../core/enums/transaction_status.dart';
import '../../core/enums/transaction_type.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed money-movement service covering deposit, withdraw, and
/// transfer. Each call is idempotent and rate-limited on the server.
class TransferService {
  TransferService(this._api);

  final ApiClient _api;

  Future<Transaction> deposit({
    required double amount,
    required String currency,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/money/deposit',
      idempotent: true,
      body: {
        'amount': amount.toStringAsFixed(2),
        'currency': currency.toUpperCase(),
      },
    );
    return _txFrom((data?['transaction'] as Map<String, dynamic>?) ?? {});
  }

  Future<Transaction> withdraw({
    required double amount,
    required String currency,
    required String bankId,
    String? narration,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/money/withdraw',
      idempotent: true,
      body: {
        'amount': amount.toStringAsFixed(2),
        'currency': currency.toUpperCase(),
        'bank_id': bankId,
        'narration': narration ?? '',
      },
    );
    return _txFrom((data?['transaction'] as Map<String, dynamic>?) ?? {});
  }

  /// Transfers within the user's own accounts (to savings) or to an external
  /// recipient (bank transfer / send to beneficiary).
  Future<Transaction> transfer({
    required double amount,
    required String currency,
    String? toKind,
    String? accountName,
    String? accountNumber,
    String? bankName,
    String? narration,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/money/transfer',
      idempotent: true,
      body: {
        'amount': amount.toStringAsFixed(2),
        'currency': currency.toUpperCase(),
        'to_kind': toKind ?? '',
        'account_name': accountName ?? '',
        'account_number': accountNumber ?? '',
        'bank_name': bankName ?? '',
        'narration': narration ?? '',
      },
    );
    return _txFrom((data?['transaction'] as Map<String, dynamic>?) ?? {});
  }

  Transaction _txFrom(Map<String, dynamic> j) {
    final currency = (j['currency'] as String? ?? 'NGN').toUpperCase();
    final type = _typeFrom(j['type'] as String? ?? '');
    return Transaction(
      id: j['id'] as String? ?? '',
      type: type,
      amount: double.tryParse(j['amount'] as String? ?? '0') ?? 0,
      currency: currency,
      status: _statusFrom(j['status'] as String? ?? ''),
      date: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      reference: j['reference'] as String?,
      fee: double.tryParse(j['fee'] as String? ?? ''),
      exchangeRate: double.tryParse(j['exchange_rate'] as String? ?? ''),
      destination: j['destination'] as String?,
    );
  }

  TransactionType _typeFrom(String raw) => switch (raw.toLowerCase()) {
        'deposit' => TransactionType.deposit,
        'withdrawal' => TransactionType.withdrawal,
        'conversion' => TransactionType.conversion,
        'transfer' => TransactionType.transfer,
        'savings' => TransactionType.savings,
        _ => TransactionType.transfer,
      };

  TransactionStatus _statusFrom(String raw) => switch (raw.toLowerCase()) {
        'initiated' => TransactionStatus.initiated,
        'processing' => TransactionStatus.processing,
        'completed' => TransactionStatus.completed,
        'failed' => TransactionStatus.failed,
        'cancelled' => TransactionStatus.cancelled,
        'reversed' => TransactionStatus.reversed,
        _ => TransactionStatus.completed,
      };
}
