// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Account _$AccountFromJson(Map<String, dynamic> json) {
  return _Account.fromJson(json);
}

/// @nodoc
mixin _$Account {
  String get id => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  double get balance => throw _privateConstructorUsedError;
  double? get usdtEquivalent => throw _privateConstructorUsedError;
  double? get exchangeRate => throw _privateConstructorUsedError;
  DateTime? get rateTimestamp => throw _privateConstructorUsedError;

  /// Serializes this Account to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountCopyWith<Account> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountCopyWith<$Res> {
  factory $AccountCopyWith(Account value, $Res Function(Account) then) =
      _$AccountCopyWithImpl<$Res, Account>;
  @useResult
  $Res call({
    String id,
    String currency,
    double balance,
    double? usdtEquivalent,
    double? exchangeRate,
    DateTime? rateTimestamp,
  });
}

/// @nodoc
class _$AccountCopyWithImpl<$Res, $Val extends Account>
    implements $AccountCopyWith<$Res> {
  _$AccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? currency = null,
    Object? balance = null,
    Object? usdtEquivalent = freezed,
    Object? exchangeRate = freezed,
    Object? rateTimestamp = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            currency: null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String,
            balance: null == balance
                ? _value.balance
                : balance // ignore: cast_nullable_to_non_nullable
                      as double,
            usdtEquivalent: freezed == usdtEquivalent
                ? _value.usdtEquivalent
                : usdtEquivalent // ignore: cast_nullable_to_non_nullable
                      as double?,
            exchangeRate: freezed == exchangeRate
                ? _value.exchangeRate
                : exchangeRate // ignore: cast_nullable_to_non_nullable
                      as double?,
            rateTimestamp: freezed == rateTimestamp
                ? _value.rateTimestamp
                : rateTimestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AccountImplCopyWith<$Res> implements $AccountCopyWith<$Res> {
  factory _$$AccountImplCopyWith(
    _$AccountImpl value,
    $Res Function(_$AccountImpl) then,
  ) = __$$AccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String currency,
    double balance,
    double? usdtEquivalent,
    double? exchangeRate,
    DateTime? rateTimestamp,
  });
}

/// @nodoc
class __$$AccountImplCopyWithImpl<$Res>
    extends _$AccountCopyWithImpl<$Res, _$AccountImpl>
    implements _$$AccountImplCopyWith<$Res> {
  __$$AccountImplCopyWithImpl(
    _$AccountImpl _value,
    $Res Function(_$AccountImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? currency = null,
    Object? balance = null,
    Object? usdtEquivalent = freezed,
    Object? exchangeRate = freezed,
    Object? rateTimestamp = freezed,
  }) {
    return _then(
      _$AccountImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        currency: null == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String,
        balance: null == balance
            ? _value.balance
            : balance // ignore: cast_nullable_to_non_nullable
                  as double,
        usdtEquivalent: freezed == usdtEquivalent
            ? _value.usdtEquivalent
            : usdtEquivalent // ignore: cast_nullable_to_non_nullable
                  as double?,
        exchangeRate: freezed == exchangeRate
            ? _value.exchangeRate
            : exchangeRate // ignore: cast_nullable_to_non_nullable
                  as double?,
        rateTimestamp: freezed == rateTimestamp
            ? _value.rateTimestamp
            : rateTimestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AccountImpl implements _Account {
  const _$AccountImpl({
    required this.id,
    required this.currency,
    required this.balance,
    this.usdtEquivalent,
    this.exchangeRate,
    this.rateTimestamp,
  });

  factory _$AccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$AccountImplFromJson(json);

  @override
  final String id;
  @override
  final String currency;
  @override
  final double balance;
  @override
  final double? usdtEquivalent;
  @override
  final double? exchangeRate;
  @override
  final DateTime? rateTimestamp;

  @override
  String toString() {
    return 'Account(id: $id, currency: $currency, balance: $balance, usdtEquivalent: $usdtEquivalent, exchangeRate: $exchangeRate, rateTimestamp: $rateTimestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.usdtEquivalent, usdtEquivalent) ||
                other.usdtEquivalent == usdtEquivalent) &&
            (identical(other.exchangeRate, exchangeRate) ||
                other.exchangeRate == exchangeRate) &&
            (identical(other.rateTimestamp, rateTimestamp) ||
                other.rateTimestamp == rateTimestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    currency,
    balance,
    usdtEquivalent,
    exchangeRate,
    rateTimestamp,
  );

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      __$$AccountImplCopyWithImpl<_$AccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AccountImplToJson(this);
  }
}

abstract class _Account implements Account {
  const factory _Account({
    required final String id,
    required final String currency,
    required final double balance,
    final double? usdtEquivalent,
    final double? exchangeRate,
    final DateTime? rateTimestamp,
  }) = _$AccountImpl;

  factory _Account.fromJson(Map<String, dynamic> json) = _$AccountImpl.fromJson;

  @override
  String get id;
  @override
  String get currency;
  @override
  double get balance;
  @override
  double? get usdtEquivalent;
  @override
  double? get exchangeRate;
  @override
  DateTime? get rateTimestamp;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AccountSummary _$AccountSummaryFromJson(Map<String, dynamic> json) {
  return _AccountSummary.fromJson(json);
}

/// @nodoc
mixin _$AccountSummary {
  Account get savings => throw _privateConstructorUsedError;
  Account get available => throw _privateConstructorUsedError;
  double get totalNgnEquivalent => throw _privateConstructorUsedError;
  double get totalUsdtEquivalent => throw _privateConstructorUsedError;
  double get currentRate => throw _privateConstructorUsedError;

  /// Serializes this AccountSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountSummaryCopyWith<AccountSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountSummaryCopyWith<$Res> {
  factory $AccountSummaryCopyWith(
    AccountSummary value,
    $Res Function(AccountSummary) then,
  ) = _$AccountSummaryCopyWithImpl<$Res, AccountSummary>;
  @useResult
  $Res call({
    Account savings,
    Account available,
    double totalNgnEquivalent,
    double totalUsdtEquivalent,
    double currentRate,
  });

  $AccountCopyWith<$Res> get savings;
  $AccountCopyWith<$Res> get available;
}

/// @nodoc
class _$AccountSummaryCopyWithImpl<$Res, $Val extends AccountSummary>
    implements $AccountSummaryCopyWith<$Res> {
  _$AccountSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? savings = null,
    Object? available = null,
    Object? totalNgnEquivalent = null,
    Object? totalUsdtEquivalent = null,
    Object? currentRate = null,
  }) {
    return _then(
      _value.copyWith(
            savings: null == savings
                ? _value.savings
                : savings // ignore: cast_nullable_to_non_nullable
                      as Account,
            available: null == available
                ? _value.available
                : available // ignore: cast_nullable_to_non_nullable
                      as Account,
            totalNgnEquivalent: null == totalNgnEquivalent
                ? _value.totalNgnEquivalent
                : totalNgnEquivalent // ignore: cast_nullable_to_non_nullable
                      as double,
            totalUsdtEquivalent: null == totalUsdtEquivalent
                ? _value.totalUsdtEquivalent
                : totalUsdtEquivalent // ignore: cast_nullable_to_non_nullable
                      as double,
            currentRate: null == currentRate
                ? _value.currentRate
                : currentRate // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }

  /// Create a copy of AccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AccountCopyWith<$Res> get savings {
    return $AccountCopyWith<$Res>(_value.savings, (value) {
      return _then(_value.copyWith(savings: value) as $Val);
    });
  }

  /// Create a copy of AccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AccountCopyWith<$Res> get available {
    return $AccountCopyWith<$Res>(_value.available, (value) {
      return _then(_value.copyWith(available: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AccountSummaryImplCopyWith<$Res>
    implements $AccountSummaryCopyWith<$Res> {
  factory _$$AccountSummaryImplCopyWith(
    _$AccountSummaryImpl value,
    $Res Function(_$AccountSummaryImpl) then,
  ) = __$$AccountSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Account savings,
    Account available,
    double totalNgnEquivalent,
    double totalUsdtEquivalent,
    double currentRate,
  });

  @override
  $AccountCopyWith<$Res> get savings;
  @override
  $AccountCopyWith<$Res> get available;
}

/// @nodoc
class __$$AccountSummaryImplCopyWithImpl<$Res>
    extends _$AccountSummaryCopyWithImpl<$Res, _$AccountSummaryImpl>
    implements _$$AccountSummaryImplCopyWith<$Res> {
  __$$AccountSummaryImplCopyWithImpl(
    _$AccountSummaryImpl _value,
    $Res Function(_$AccountSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? savings = null,
    Object? available = null,
    Object? totalNgnEquivalent = null,
    Object? totalUsdtEquivalent = null,
    Object? currentRate = null,
  }) {
    return _then(
      _$AccountSummaryImpl(
        savings: null == savings
            ? _value.savings
            : savings // ignore: cast_nullable_to_non_nullable
                  as Account,
        available: null == available
            ? _value.available
            : available // ignore: cast_nullable_to_non_nullable
                  as Account,
        totalNgnEquivalent: null == totalNgnEquivalent
            ? _value.totalNgnEquivalent
            : totalNgnEquivalent // ignore: cast_nullable_to_non_nullable
                  as double,
        totalUsdtEquivalent: null == totalUsdtEquivalent
            ? _value.totalUsdtEquivalent
            : totalUsdtEquivalent // ignore: cast_nullable_to_non_nullable
                  as double,
        currentRate: null == currentRate
            ? _value.currentRate
            : currentRate // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AccountSummaryImpl implements _AccountSummary {
  const _$AccountSummaryImpl({
    required this.savings,
    required this.available,
    required this.totalNgnEquivalent,
    required this.totalUsdtEquivalent,
    required this.currentRate,
  });

  factory _$AccountSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$AccountSummaryImplFromJson(json);

  @override
  final Account savings;
  @override
  final Account available;
  @override
  final double totalNgnEquivalent;
  @override
  final double totalUsdtEquivalent;
  @override
  final double currentRate;

  @override
  String toString() {
    return 'AccountSummary(savings: $savings, available: $available, totalNgnEquivalent: $totalNgnEquivalent, totalUsdtEquivalent: $totalUsdtEquivalent, currentRate: $currentRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountSummaryImpl &&
            (identical(other.savings, savings) || other.savings == savings) &&
            (identical(other.available, available) ||
                other.available == available) &&
            (identical(other.totalNgnEquivalent, totalNgnEquivalent) ||
                other.totalNgnEquivalent == totalNgnEquivalent) &&
            (identical(other.totalUsdtEquivalent, totalUsdtEquivalent) ||
                other.totalUsdtEquivalent == totalUsdtEquivalent) &&
            (identical(other.currentRate, currentRate) ||
                other.currentRate == currentRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    savings,
    available,
    totalNgnEquivalent,
    totalUsdtEquivalent,
    currentRate,
  );

  /// Create a copy of AccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountSummaryImplCopyWith<_$AccountSummaryImpl> get copyWith =>
      __$$AccountSummaryImplCopyWithImpl<_$AccountSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AccountSummaryImplToJson(this);
  }
}

abstract class _AccountSummary implements AccountSummary {
  const factory _AccountSummary({
    required final Account savings,
    required final Account available,
    required final double totalNgnEquivalent,
    required final double totalUsdtEquivalent,
    required final double currentRate,
  }) = _$AccountSummaryImpl;

  factory _AccountSummary.fromJson(Map<String, dynamic> json) =
      _$AccountSummaryImpl.fromJson;

  @override
  Account get savings;
  @override
  Account get available;
  @override
  double get totalNgnEquivalent;
  @override
  double get totalUsdtEquivalent;
  @override
  double get currentRate;

  /// Create a copy of AccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountSummaryImplCopyWith<_$AccountSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
