import 'package:freezed_annotation/freezed_annotation.dart';

part 'beneficiary.freezed.dart';
part 'beneficiary.g.dart';

@freezed
class Beneficiary with _$Beneficiary {
  const factory Beneficiary({
    required String id,
    required String name,
    required String bank,
    required String accountNumber,
    @Default(false) bool isFavorite,
  }) = _Beneficiary;

  factory Beneficiary.fromJson(Map<String, dynamic> json) =>
      _$BeneficiaryFromJson(json);
}

extension BeneficiaryExtensions on Beneficiary {
  String get maskedNumber => '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  String get displayName => '$name — $bank ${accountNumber.substring(accountNumber.length - 4)}';
}
