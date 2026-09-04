import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums/transaction_status.dart';
import '../../core/enums/transaction_type.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed conversion service. Quotes are read-only (`POST /money/quote`)
/// and conversion execution is an idempotent, rate-limited money movement.
class ConversionService {
  ConversionService(this._api);

  final ApiClient _api;

  /// Requests a live conversion quote from the backend.
  Future<ConversionQuote> getQuote({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/money/quote',
      body: {
        'amount': _amountString(amount),
        'from_currency': fromCurrency.toUpperCase(),
        'to_currency': toCurrency.toUpperCase(),
      },
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    final q = data['quote'] as Map<String, dynamic>? ?? {};
    return ConversionQuote(
      inputAmount: double.tryParse(q['input_amount'] as String? ?? '0') ?? 0,
      inputCurrency: (q['input_currency'] as String? ?? fromCurrency).toUpperCase(),
      outputAmount: double.tryParse(q['output_amount'] as String? ?? '0') ?? 0,
      outputCurrency: (q['output_currency'] as String? ?? toCurrency).toUpperCase(),
      rate: double.tryParse(q['rate'] as String? ?? '0') ?? 0,
      fee: 0,
      feeAmount: double.tryParse(q['fee_amount'] as String? ?? '0') ?? 0,
      expiresAt: DateTime.tryParse(q['expires_at'] as String? ?? '') ??
          DateTime.now().add(AppConstants.rateExpiry),
    );
  }

  /// Executes a conversion, returning the resulting transaction.
  Future<Transaction> convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/money/convert',
      idempotent: true,
      body: {
        'amount': _amountString(amount),
        'from_currency': fromCurrency.toUpperCase(),
        'to_currency': toCurrency.toUpperCase(),
      },
    );
    final tx = data?['transaction'] as Map<String, dynamic>? ?? {};
    return _txFromApi(tx);
  }

  String _amountString(double amount) =>
      NumberFormat('#,##0.##', 'en_US').format(amount).replaceAll(',', '');

  Transaction _txFromApi(Map<String, dynamic> j) {
    return Transaction(
      id: j['id'] as String? ?? '',
      type: _typeFrom(j['type'] as String? ?? 'conversion'),
      amount: double.tryParse(j['amount'] as String? ?? '0') ?? 0,
      currency: (j['currency'] as String? ?? 'NGN').toUpperCase(),
      status: _statusFrom(j['status'] as String? ?? 'completed'),
      date: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      reference: j['reference'] as String?,
      fee: double.tryParse(j['fee'] as String? ?? ''),
      exchangeRate: double.tryParse(j['exchange_rate'] as String? ?? ''),
    );
  }
}

TransactionType _typeFrom(String raw) => switch (raw.toLowerCase()) {
      'deposit' => TransactionType.deposit,
      'withdrawal' => TransactionType.withdrawal,
      'conversion' => TransactionType.conversion,
      'transfer' => TransactionType.transfer,
      'savings' => TransactionType.savings,
      _ => TransactionType.conversion,
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
