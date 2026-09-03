import 'package:freezed_annotation/freezed_annotation.dart';

part 'bank_account.freezed.dart';
part 'bank_account.g.dart';

@freezed
class BankAccount with _$BankAccount {
  const factory BankAccount({
    required String id,
    required String bankName,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    @Default(false) bool isDefault,
  }) = _BankAccount;

  factory BankAccount.fromJson(Map<String, dynamic> json) =>
      _$BankAccountFromJson(json);
}

extension BankAccountExtensions on BankAccount {
  String get maskedNumber => '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  String get displayName => '$bankName •••• ${accountNumber.substring(accountNumber.length - 4)}';
}
