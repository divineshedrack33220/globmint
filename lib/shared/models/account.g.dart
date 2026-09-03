// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccountImpl _$$AccountImplFromJson(Map<String, dynamic> json) =>
    _$AccountImpl(
      id: json['id'] as String,
      currency: json['currency'] as String,
      balance: (json['balance'] as num).toDouble(),
      usdtEquivalent: (json['usdtEquivalent'] as num?)?.toDouble(),
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      rateTimestamp: json['rateTimestamp'] == null
          ? null
          : DateTime.parse(json['rateTimestamp'] as String),
    );

Map<String, dynamic> _$$AccountImplToJson(_$AccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'currency': instance.currency,
      'balance': instance.balance,
      'usdtEquivalent': instance.usdtEquivalent,
      'exchangeRate': instance.exchangeRate,
      'rateTimestamp': instance.rateTimestamp?.toIso8601String(),
    };

_$AccountSummaryImpl _$$AccountSummaryImplFromJson(Map<String, dynamic> json) =>
    _$AccountSummaryImpl(
      savings: Account.fromJson(json['savings'] as Map<String, dynamic>),
      available: Account.fromJson(json['available'] as Map<String, dynamic>),
      totalNgnEquivalent: (json['totalNgnEquivalent'] as num).toDouble(),
      totalUsdtEquivalent: (json['totalUsdtEquivalent'] as num).toDouble(),
      currentRate: (json['currentRate'] as num).toDouble(),
    );

Map<String, dynamic> _$$AccountSummaryImplToJson(
  _$AccountSummaryImpl instance,
) => <String, dynamic>{
  'savings': instance.savings,
  'available': instance.available,
  'totalNgnEquivalent': instance.totalNgnEquivalent,
  'totalUsdtEquivalent': instance.totalUsdtEquivalent,
  'currentRate': instance.currentRate,
};
