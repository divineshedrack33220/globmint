import 'package:freezed_annotation/freezed_annotation.dart';

part 'beneficiary.freezed.dart';
part 'beneficiary.g.dart';

@freezed
class Beneficiary with _$Beneficiary {
  const factory Beneficiary({
    required String id,
    required String name,
    required String address,
    @Default(false) bool isFavorite,
  }) = _Beneficiary;

  factory Beneficiary.fromJson(Map<String, dynamic> json) =>
      _$BeneficiaryFromJson(json);
}

extension BeneficiaryExtensions on Beneficiary {
  /// Short label like `0x1a0f…5678` for on-screen display.
  String get shortAddress {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
}