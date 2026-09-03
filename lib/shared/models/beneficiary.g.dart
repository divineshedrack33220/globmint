// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'beneficiary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BeneficiaryImpl _$$BeneficiaryImplFromJson(Map<String, dynamic> json) =>
    _$BeneficiaryImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      bank: json['bank'] as String,
      accountNumber: json['accountNumber'] as String,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );

Map<String, dynamic> _$$BeneficiaryImplToJson(_$BeneficiaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'bank': instance.bank,
      'accountNumber': instance.accountNumber,
      'isFavorite': instance.isFavorite,
    };
