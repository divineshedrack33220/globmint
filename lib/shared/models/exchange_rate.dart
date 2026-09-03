import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_rate.freezed.dart';
part 'exchange_rate.g.dart';

@freezed
class ExchangeRate with _$ExchangeRate {
  const factory ExchangeRate({
    required String pair,
    required double rate,
    required double inverseRate,
    required double fee,
    required double minAmount,
    required double maxAmount,
    required DateTime timestamp,
    required DateTime expiresAt,
    required String status,
  }) = _ExchangeRate;

  factory ExchangeRate.fromJson(Map<String, dynamic> json) =>
      _$ExchangeRateFromJson(json);
}

@freezed
class ConversionQuote with _$ConversionQuote {
  const factory ConversionQuote({
    required double inputAmount,
    required String inputCurrency,
    required double outputAmount,
    required String outputCurrency,
    required double rate,
    required double fee,
    required double feeAmount,
    required DateTime expiresAt,
  }) = _ConversionQuote;

  factory ConversionQuote.fromJson(Map<String, dynamic> json) =>
      _$ConversionQuoteFromJson(json);
}

extension ConversionQuoteExtensions on ConversionQuote {
  double get netAmount => outputAmount;
  double get totalDeducted => inputAmount;
}
