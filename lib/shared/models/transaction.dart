import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/enums/transaction_status.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required TransactionType type,
    required double amount,
    required String currency,
    required TransactionStatus status,
    required DateTime date,
    String? description,
    String? reference,
    String? destination,
    String? fromCurrency,
    String? toCurrency,
    double? convertedAmount,
    double? exchangeRate,
    double? fee,
    String? failureReason,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}

extension TransactionExtensions on Transaction {
  bool get isPositive =>
      type == TransactionType.deposit ||
      type == TransactionType.conversion && toCurrency == 'USDT';

  String get displayCurrency => currency;
}
