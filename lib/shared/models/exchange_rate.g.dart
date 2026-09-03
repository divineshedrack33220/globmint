// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExchangeRateImpl _$$ExchangeRateImplFromJson(Map<String, dynamic> json) =>
    _$ExchangeRateImpl(
      pair: json['pair'] as String,
      rate: (json['rate'] as num).toDouble(),
      inverseRate: (json['inverseRate'] as num).toDouble(),
      fee: (json['fee'] as num).toDouble(),
      minAmount: (json['minAmount'] as num).toDouble(),
      maxAmount: (json['maxAmount'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      status: json['status'] as String,
    );

Map<String, dynamic> _$$ExchangeRateImplToJson(_$ExchangeRateImpl instance) =>
    <String, dynamic>{
      'pair': instance.pair,
      'rate': instance.rate,
      'inverseRate': instance.inverseRate,
      'fee': instance.fee,
      'minAmount': instance.minAmount,
      'maxAmount': instance.maxAmount,
      'timestamp': instance.timestamp.toIso8601String(),
      'expiresAt': instance.expiresAt.toIso8601String(),
      'status': instance.status,
    };

_$ConversionQuoteImpl _$$ConversionQuoteImplFromJson(
  Map<String, dynamic> json,
) => _$ConversionQuoteImpl(
  inputAmount: (json['inputAmount'] as num).toDouble(),
  inputCurrency: json['inputCurrency'] as String,
  outputAmount: (json['outputAmount'] as num).toDouble(),
  outputCurrency: json['outputCurrency'] as String,
  rate: (json['rate'] as num).toDouble(),
  fee: (json['fee'] as num).toDouble(),
  feeAmount: (json['feeAmount'] as num).toDouble(),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$$ConversionQuoteImplToJson(
  _$ConversionQuoteImpl instance,
) => <String, dynamic>{
  'inputAmount': instance.inputAmount,
  'inputCurrency': instance.inputCurrency,
  'outputAmount': instance.outputAmount,
  'outputCurrency': instance.outputCurrency,
  'rate': instance.rate,
  'fee': instance.fee,
  'feeAmount': instance.feeAmount,
  'expiresAt': instance.expiresAt.toIso8601String(),
};
