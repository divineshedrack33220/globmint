// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      id: json['id'] as String,
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: $enumDecode(_$TransactionStatusEnumMap, json['status']),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
      reference: json['reference'] as String?,
      destination: json['destination'] as String?,
      fromCurrency: json['fromCurrency'] as String?,
      toCurrency: json['toCurrency'] as String?,
      convertedAmount: (json['convertedAmount'] as num?)?.toDouble(),
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      fee: (json['fee'] as num?)?.toDouble(),
      failureReason: json['failureReason'] as String?,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'amount': instance.amount,
      'currency': instance.currency,
      'status': _$TransactionStatusEnumMap[instance.status]!,
      'date': instance.date.toIso8601String(),
      'description': instance.description,
      'reference': instance.reference,
      'destination': instance.destination,
      'fromCurrency': instance.fromCurrency,
      'toCurrency': instance.toCurrency,
      'convertedAmount': instance.convertedAmount,
      'exchangeRate': instance.exchangeRate,
      'fee': instance.fee,
      'failureReason': instance.failureReason,
    };

const _$TransactionTypeEnumMap = {
  TransactionType.deposit: 'deposit',
  TransactionType.withdrawal: 'withdrawal',
  TransactionType.conversion: 'conversion',
  TransactionType.transfer: 'transfer',
  TransactionType.savings: 'savings',
};

const _$TransactionStatusEnumMap = {
  TransactionStatus.initiated: 'initiated',
  TransactionStatus.processing: 'processing',
  TransactionStatus.completed: 'completed',
  TransactionStatus.failed: 'failed',
  TransactionStatus.cancelled: 'cancelled',
  TransactionStatus.reversed: 'reversed',
};
