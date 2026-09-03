// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  String get id => throw _privateConstructorUsedError;
  TransactionType get type => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  TransactionStatus get status => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get reference => throw _privateConstructorUsedError;
  String? get destination => throw _privateConstructorUsedError;
  String? get fromCurrency => throw _privateConstructorUsedError;
  String? get toCurrency => throw _privateConstructorUsedError;
  double? get convertedAmount => throw _privateConstructorUsedError;
  double? get exchangeRate => throw _privateConstructorUsedError;
  double? get fee => throw _privateConstructorUsedError;
  String? get failureReason => throw _privateConstructorUsedError;

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
    Transaction value,
    $Res Function(Transaction) then,
  ) = _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call({
    String id,
    TransactionType type,
    double amount,
    String currency,
    TransactionStatus status,
    DateTime date,
    String? description,
    String? reference,
    String? destination,
    String? fromCurrency,
    String? toCurrency,
    double? convertedAmount,
    double? exchangeRate,
    double? fee,
    String? failureReason,
  });
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? amount = null,
    Object? currency = null,
    Object? status = null,
    Object? date = null,
    Object? description = freezed,
    Object? reference = freezed,
    Object? destination = freezed,
    Object? fromCurrency = freezed,
    Object? toCurrency = freezed,
    Object? convertedAmount = freezed,
    Object? exchangeRate = freezed,
    Object? fee = freezed,
    Object? failureReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as TransactionType,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as double,
            currency: null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TransactionStatus,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            reference: freezed == reference
                ? _value.reference
                : reference // ignore: cast_nullable_to_non_nullable
                      as String?,
            destination: freezed == destination
                ? _value.destination
                : destination // ignore: cast_nullable_to_non_nullable
                      as String?,
            fromCurrency: freezed == fromCurrency
                ? _value.fromCurrency
                : fromCurrency // ignore: cast_nullable_to_non_nullable
                      as String?,
            toCurrency: freezed == toCurrency
                ? _value.toCurrency
                : toCurrency // ignore: cast_nullable_to_non_nullable
                      as String?,
            convertedAmount: freezed == convertedAmount
                ? _value.convertedAmount
                : convertedAmount // ignore: cast_nullable_to_non_nullable
                      as double?,
            exchangeRate: freezed == exchangeRate
                ? _value.exchangeRate
                : exchangeRate // ignore: cast_nullable_to_non_nullable
                      as double?,
            fee: freezed == fee
                ? _value.fee
                : fee // ignore: cast_nullable_to_non_nullable
                      as double?,
            failureReason: freezed == failureReason
                ? _value.failureReason
                : failureReason // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
    _$TransactionImpl value,
    $Res Function(_$TransactionImpl) then,
  ) = __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    TransactionType type,
    double amount,
    String currency,
    TransactionStatus status,
    DateTime date,
    String? description,
    String? reference,
    String? destination,
    String? fromCurrency,
    String? toCurrency,
    double? convertedAmount,
    double? exchangeRate,
    double? fee,
    String? failureReason,
  });
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
    _$TransactionImpl _value,
    $Res Function(_$TransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? amount = null,
    Object? currency = null,
    Object? status = null,
    Object? date = null,
    Object? description = freezed,
    Object? reference = freezed,
    Object? destination = freezed,
    Object? fromCurrency = freezed,
    Object? toCurrency = freezed,
    Object? convertedAmount = freezed,
    Object? exchangeRate = freezed,
    Object? fee = freezed,
    Object? failureReason = freezed,
  }) {
    return _then(
      _$TransactionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as TransactionType,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as double,
        currency: null == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TransactionStatus,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        reference: freezed == reference
            ? _value.reference
            : reference // ignore: cast_nullable_to_non_nullable
                  as String?,
        destination: freezed == destination
            ? _value.destination
            : destination // ignore: cast_nullable_to_non_nullable
                  as String?,
        fromCurrency: freezed == fromCurrency
            ? _value.fromCurrency
            : fromCurrency // ignore: cast_nullable_to_non_nullable
                  as String?,
        toCurrency: freezed == toCurrency
            ? _value.toCurrency
            : toCurrency // ignore: cast_nullable_to_non_nullable
                  as String?,
        convertedAmount: freezed == convertedAmount
            ? _value.convertedAmount
            : convertedAmount // ignore: cast_nullable_to_non_nullable
                  as double?,
        exchangeRate: freezed == exchangeRate
            ? _value.exchangeRate
            : exchangeRate // ignore: cast_nullable_to_non_nullable
                  as double?,
        fee: freezed == fee
            ? _value.fee
            : fee // ignore: cast_nullable_to_non_nullable
                  as double?,
        failureReason: freezed == failureReason
            ? _value.failureReason
            : failureReason // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl implements _Transaction {
  const _$TransactionImpl({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.date,
    this.description,
    this.reference,
    this.destination,
    this.fromCurrency,
    this.toCurrency,
    this.convertedAmount,
    this.exchangeRate,
    this.fee,
    this.failureReason,
  });

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final String id;
  @override
  final TransactionType type;
  @override
  final double amount;
  @override
  final String currency;
  @override
  final TransactionStatus status;
  @override
  final DateTime date;
  @override
  final String? description;
  @override
  final String? reference;
  @override
  final String? destination;
  @override
  final String? fromCurrency;
  @override
  final String? toCurrency;
  @override
  final double? convertedAmount;
  @override
  final double? exchangeRate;
  @override
  final double? fee;
  @override
  final String? failureReason;

  @override
  String toString() {
    return 'Transaction(id: $id, type: $type, amount: $amount, currency: $currency, status: $status, date: $date, description: $description, reference: $reference, destination: $destination, fromCurrency: $fromCurrency, toCurrency: $toCurrency, convertedAmount: $convertedAmount, exchangeRate: $exchangeRate, fee: $fee, failureReason: $failureReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.reference, reference) ||
                other.reference == reference) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.fromCurrency, fromCurrency) ||
                other.fromCurrency == fromCurrency) &&
            (identical(other.toCurrency, toCurrency) ||
                other.toCurrency == toCurrency) &&
            (identical(other.convertedAmount, convertedAmount) ||
                other.convertedAmount == convertedAmount) &&
            (identical(other.exchangeRate, exchangeRate) ||
                other.exchangeRate == exchangeRate) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            (identical(other.failureReason, failureReason) ||
                other.failureReason == failureReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    amount,
    currency,
    status,
    date,
    description,
    reference,
    destination,
    fromCurrency,
    toCurrency,
    convertedAmount,
    exchangeRate,
    fee,
    failureReason,
  );

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(this);
  }
}

abstract class _Transaction implements Transaction {
  const factory _Transaction({
    required final String id,
    required final TransactionType type,
    required final double amount,
    required final String currency,
    required final TransactionStatus status,
    required final DateTime date,
    final String? description,
    final String? reference,
    final String? destination,
    final String? fromCurrency,
    final String? toCurrency,
    final double? convertedAmount,
    final double? exchangeRate,
    final double? fee,
    final String? failureReason,
  }) = _$TransactionImpl;

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  String get id;
  @override
  TransactionType get type;
  @override
  double get amount;
  @override
  String get currency;
  @override
  TransactionStatus get status;
  @override
  DateTime get date;
  @override
  String? get description;
  @override
  String? get reference;
  @override
  String? get destination;
  @override
  String? get fromCurrency;
  @override
  String? get toCurrency;
  @override
  double? get convertedAmount;
  @override
  double? get exchangeRate;
  @override
  double? get fee;
  @override
  String? get failureReason;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
