// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BankAccountImpl _$$BankAccountImplFromJson(Map<String, dynamic> json) =>
    _$BankAccountImpl(
      id: json['id'] as String,
      bankName: json['bankName'] as String,
      bankCode: json['bankCode'] as String,
      accountNumber: json['accountNumber'] as String,
      accountName: json['accountName'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$$BankAccountImplToJson(_$BankAccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bankName': instance.bankName,
      'bankCode': instance.bankCode,
      'accountNumber': instance.accountNumber,
      'accountName': instance.accountName,
      'isDefault': instance.isDefault,
    };
