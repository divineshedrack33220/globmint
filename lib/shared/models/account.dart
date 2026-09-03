import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    required String currency,
    required double balance,
    double? usdtEquivalent,
    double? exchangeRate,
    DateTime? rateTimestamp,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);
}

@freezed
class AccountSummary with _$AccountSummary {
  const factory AccountSummary({
    required Account savings,
    required Account available,
    required double totalNgnEquivalent,
    required double totalUsdtEquivalent,
    required double currentRate,
  }) = _AccountSummary;

  factory AccountSummary.fromJson(Map<String, dynamic> json) =>
      _$AccountSummaryFromJson(json);
}
