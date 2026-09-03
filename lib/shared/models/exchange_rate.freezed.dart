// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exchange_rate.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ExchangeRate _$ExchangeRateFromJson(Map<String, dynamic> json) {
  return _ExchangeRate.fromJson(json);
}

/// @nodoc
mixin _$ExchangeRate {
  String get pair => throw _privateConstructorUsedError;
  double get rate => throw _privateConstructorUsedError;
  double get inverseRate => throw _privateConstructorUsedError;
  double get fee => throw _privateConstructorUsedError;
  double get minAmount => throw _privateConstructorUsedError;
  double get maxAmount => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this ExchangeRate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExchangeRate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExchangeRateCopyWith<ExchangeRate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExchangeRateCopyWith<$Res> {
  factory $ExchangeRateCopyWith(
    ExchangeRate value,
    $Res Function(ExchangeRate) then,
  ) = _$ExchangeRateCopyWithImpl<$Res, ExchangeRate>;
  @useResult
  $Res call({
    String pair,
    double rate,
    double inverseRate,
    double fee,
    double minAmount,
    double maxAmount,
    DateTime timestamp,
    DateTime expiresAt,
    String status,
  });
}

/// @nodoc
class _$ExchangeRateCopyWithImpl<$Res, $Val extends ExchangeRate>
    implements $ExchangeRateCopyWith<$Res> {
  _$ExchangeRateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExchangeRate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pair = null,
    Object? rate = null,
    Object? inverseRate = null,
    Object? fee = null,
    Object? minAmount = null,
    Object? maxAmount = null,
    Object? timestamp = null,
    Object? expiresAt = null,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            pair: null == pair
                ? _value.pair
                : pair // ignore: cast_nullable_to_non_nullable
                      as String,
            rate: null == rate
                ? _value.rate
                : rate // ignore: cast_nullable_to_non_nullable
                      as double,
            inverseRate: null == inverseRate
                ? _value.inverseRate
                : inverseRate // ignore: cast_nullable_to_non_nullable
                      as double,
            fee: null == fee
                ? _value.fee
                : fee // ignore: cast_nullable_to_non_nullable
                      as double,
            minAmount: null == minAmount
                ? _value.minAmount
                : minAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            maxAmount: null == maxAmount
                ? _value.maxAmount
                : maxAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExchangeRateImplCopyWith<$Res>
    implements $ExchangeRateCopyWith<$Res> {
  factory _$$ExchangeRateImplCopyWith(
    _$ExchangeRateImpl value,
    $Res Function(_$ExchangeRateImpl) then,
  ) = __$$ExchangeRateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String pair,
    double rate,
    double inverseRate,
    double fee,
    double minAmount,
    double maxAmount,
    DateTime timestamp,
    DateTime expiresAt,
    String status,
  });
}

/// @nodoc
class __$$ExchangeRateImplCopyWithImpl<$Res>
    extends _$ExchangeRateCopyWithImpl<$Res, _$ExchangeRateImpl>
    implements _$$ExchangeRateImplCopyWith<$Res> {
  __$$ExchangeRateImplCopyWithImpl(
    _$ExchangeRateImpl _value,
    $Res Function(_$ExchangeRateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExchangeRate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pair = null,
    Object? rate = null,
    Object? inverseRate = null,
    Object? fee = null,
    Object? minAmount = null,
    Object? maxAmount = null,
    Object? timestamp = null,
    Object? expiresAt = null,
    Object? status = null,
  }) {
    return _then(
      _$ExchangeRateImpl(
        pair: null == pair
            ? _value.pair
            : pair // ignore: cast_nullable_to_non_nullable
                  as String,
        rate: null == rate
            ? _value.rate
            : rate // ignore: cast_nullable_to_non_nullable
                  as double,
        inverseRate: null == inverseRate
            ? _value.inverseRate
            : inverseRate // ignore: cast_nullable_to_non_nullable
                  as double,
        fee: null == fee
            ? _value.fee
            : fee // ignore: cast_nullable_to_non_nullable
                  as double,
        minAmount: null == minAmount
            ? _value.minAmount
            : minAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        maxAmount: null == maxAmount
            ? _value.maxAmount
            : maxAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExchangeRateImpl implements _ExchangeRate {
  const _$ExchangeRateImpl({
    required this.pair,
    required this.rate,
    required this.inverseRate,
    required this.fee,
    required this.minAmount,
    required this.maxAmount,
    required this.timestamp,
    required this.expiresAt,
    required this.status,
  });

  factory _$ExchangeRateImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExchangeRateImplFromJson(json);

  @override
  final String pair;
  @override
  final double rate;
  @override
  final double inverseRate;
  @override
  final double fee;
  @override
  final double minAmount;
  @override
  final double maxAmount;
  @override
  final DateTime timestamp;
  @override
  final DateTime expiresAt;
  @override
  final String status;

  @override
  String toString() {
    return 'ExchangeRate(pair: $pair, rate: $rate, inverseRate: $inverseRate, fee: $fee, minAmount: $minAmount, maxAmount: $maxAmount, timestamp: $timestamp, expiresAt: $expiresAt, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExchangeRateImpl &&
            (identical(other.pair, pair) || other.pair == pair) &&
            (identical(other.rate, rate) || other.rate == rate) &&
            (identical(other.inverseRate, inverseRate) ||
                other.inverseRate == inverseRate) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.maxAmount, maxAmount) ||
                other.maxAmount == maxAmount) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    pair,
    rate,
    inverseRate,
    fee,
    minAmount,
    maxAmount,
    timestamp,
    expiresAt,
    status,
  );

  /// Create a copy of ExchangeRate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExchangeRateImplCopyWith<_$ExchangeRateImpl> get copyWith =>
      __$$ExchangeRateImplCopyWithImpl<_$ExchangeRateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExchangeRateImplToJson(this);
  }
}

abstract class _ExchangeRate implements ExchangeRate {
  const factory _ExchangeRate({
    required final String pair,
    required final double rate,
    required final double inverseRate,
    required final double fee,
    required final double minAmount,
    required final double maxAmount,
    required final DateTime timestamp,
    required final DateTime expiresAt,
    required final String status,
  }) = _$ExchangeRateImpl;

  factory _ExchangeRate.fromJson(Map<String, dynamic> json) =
      _$ExchangeRateImpl.fromJson;

  @override
  String get pair;
  @override
  double get rate;
  @override
  double get inverseRate;
  @override
  double get fee;
  @override
  double get minAmount;
  @override
  double get maxAmount;
  @override
  DateTime get timestamp;
  @override
  DateTime get expiresAt;
  @override
  String get status;

  /// Create a copy of ExchangeRate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExchangeRateImplCopyWith<_$ExchangeRateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConversionQuote _$ConversionQuoteFromJson(Map<String, dynamic> json) {
  return _ConversionQuote.fromJson(json);
}

/// @nodoc
mixin _$ConversionQuote {
  double get inputAmount => throw _privateConstructorUsedError;
  String get inputCurrency => throw _privateConstructorUsedError;
  double get outputAmount => throw _privateConstructorUsedError;
  String get outputCurrency => throw _privateConstructorUsedError;
  double get rate => throw _privateConstructorUsedError;
  double get fee => throw _privateConstructorUsedError;
  double get feeAmount => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;

  /// Serializes this ConversionQuote to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConversionQuote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversionQuoteCopyWith<ConversionQuote> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversionQuoteCopyWith<$Res> {
  factory $ConversionQuoteCopyWith(
    ConversionQuote value,
    $Res Function(ConversionQuote) then,
  ) = _$ConversionQuoteCopyWithImpl<$Res, ConversionQuote>;
  @useResult
  $Res call({
    double inputAmount,
    String inputCurrency,
    double outputAmount,
    String outputCurrency,
    double rate,
    double fee,
    double feeAmount,
    DateTime expiresAt,
  });
}

/// @nodoc
class _$ConversionQuoteCopyWithImpl<$Res, $Val extends ConversionQuote>
    implements $ConversionQuoteCopyWith<$Res> {
  _$ConversionQuoteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversionQuote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputAmount = null,
    Object? inputCurrency = null,
    Object? outputAmount = null,
    Object? outputCurrency = null,
    Object? rate = null,
    Object? fee = null,
    Object? feeAmount = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _value.copyWith(
            inputAmount: null == inputAmount
                ? _value.inputAmount
                : inputAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            inputCurrency: null == inputCurrency
                ? _value.inputCurrency
                : inputCurrency // ignore: cast_nullable_to_non_nullable
                      as String,
            outputAmount: null == outputAmount
                ? _value.outputAmount
                : outputAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            outputCurrency: null == outputCurrency
                ? _value.outputCurrency
                : outputCurrency // ignore: cast_nullable_to_non_nullable
                      as String,
            rate: null == rate
                ? _value.rate
                : rate // ignore: cast_nullable_to_non_nullable
                      as double,
            fee: null == fee
                ? _value.fee
                : fee // ignore: cast_nullable_to_non_nullable
                      as double,
            feeAmount: null == feeAmount
                ? _value.feeAmount
                : feeAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConversionQuoteImplCopyWith<$Res>
    implements $ConversionQuoteCopyWith<$Res> {
  factory _$$ConversionQuoteImplCopyWith(
    _$ConversionQuoteImpl value,
    $Res Function(_$ConversionQuoteImpl) then,
  ) = __$$ConversionQuoteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double inputAmount,
    String inputCurrency,
    double outputAmount,
    String outputCurrency,
    double rate,
    double fee,
    double feeAmount,
    DateTime expiresAt,
  });
}

/// @nodoc
class __$$ConversionQuoteImplCopyWithImpl<$Res>
    extends _$ConversionQuoteCopyWithImpl<$Res, _$ConversionQuoteImpl>
    implements _$$ConversionQuoteImplCopyWith<$Res> {
  __$$ConversionQuoteImplCopyWithImpl(
    _$ConversionQuoteImpl _value,
    $Res Function(_$ConversionQuoteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversionQuote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputAmount = null,
    Object? inputCurrency = null,
    Object? outputAmount = null,
    Object? outputCurrency = null,
    Object? rate = null,
    Object? fee = null,
    Object? feeAmount = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _$ConversionQuoteImpl(
        inputAmount: null == inputAmount
            ? _value.inputAmount
            : inputAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        inputCurrency: null == inputCurrency
            ? _value.inputCurrency
            : inputCurrency // ignore: cast_nullable_to_non_nullable
                  as String,
        outputAmount: null == outputAmount
            ? _value.outputAmount
            : outputAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        outputCurrency: null == outputCurrency
            ? _value.outputCurrency
            : outputCurrency // ignore: cast_nullable_to_non_nullable
                  as String,
        rate: null == rate
            ? _value.rate
            : rate // ignore: cast_nullable_to_non_nullable
                  as double,
        fee: null == fee
            ? _value.fee
            : fee // ignore: cast_nullable_to_non_nullable
                  as double,
        feeAmount: null == feeAmount
            ? _value.feeAmount
            : feeAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConversionQuoteImpl implements _ConversionQuote {
  const _$ConversionQuoteImpl({
    required this.inputAmount,
    required this.inputCurrency,
    required this.outputAmount,
    required this.outputCurrency,
    required this.rate,
    required this.fee,
    required this.feeAmount,
    required this.expiresAt,
  });

  factory _$ConversionQuoteImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversionQuoteImplFromJson(json);

  @override
  final double inputAmount;
  @override
  final String inputCurrency;
  @override
  final double outputAmount;
  @override
  final String outputCurrency;
  @override
  final double rate;
  @override
  final double fee;
  @override
  final double feeAmount;
  @override
  final DateTime expiresAt;

  @override
  String toString() {
    return 'ConversionQuote(inputAmount: $inputAmount, inputCurrency: $inputCurrency, outputAmount: $outputAmount, outputCurrency: $outputCurrency, rate: $rate, fee: $fee, feeAmount: $feeAmount, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversionQuoteImpl &&
            (identical(other.inputAmount, inputAmount) ||
                other.inputAmount == inputAmount) &&
            (identical(other.inputCurrency, inputCurrency) ||
                other.inputCurrency == inputCurrency) &&
            (identical(other.outputAmount, outputAmount) ||
                other.outputAmount == outputAmount) &&
            (identical(other.outputCurrency, outputCurrency) ||
                other.outputCurrency == outputCurrency) &&
            (identical(other.rate, rate) || other.rate == rate) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            (identical(other.feeAmount, feeAmount) ||
                other.feeAmount == feeAmount) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    inputAmount,
    inputCurrency,
    outputAmount,
    outputCurrency,
    rate,
    fee,
    feeAmount,
    expiresAt,
  );

  /// Create a copy of ConversionQuote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversionQuoteImplCopyWith<_$ConversionQuoteImpl> get copyWith =>
      __$$ConversionQuoteImplCopyWithImpl<_$ConversionQuoteImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversionQuoteImplToJson(this);
  }
}

abstract class _ConversionQuote implements ConversionQuote {
  const factory _ConversionQuote({
    required final double inputAmount,
    required final String inputCurrency,
    required final double outputAmount,
    required final String outputCurrency,
    required final double rate,
    required final double fee,
    required final double feeAmount,
    required final DateTime expiresAt,
  }) = _$ConversionQuoteImpl;

  factory _ConversionQuote.fromJson(Map<String, dynamic> json) =
      _$ConversionQuoteImpl.fromJson;

  @override
  double get inputAmount;
  @override
  String get inputCurrency;
  @override
  double get outputAmount;
  @override
  String get outputCurrency;
  @override
  double get rate;
  @override
  double get fee;
  @override
  double get feeAmount;
  @override
  DateTime get expiresAt;

  /// Create a copy of ConversionQuote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversionQuoteImplCopyWith<_$ConversionQuoteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
