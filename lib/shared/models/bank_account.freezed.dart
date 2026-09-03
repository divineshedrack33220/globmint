// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bank_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BankAccount _$BankAccountFromJson(Map<String, dynamic> json) {
  return _BankAccount.fromJson(json);
}

/// @nodoc
mixin _$BankAccount {
  String get id => throw _privateConstructorUsedError;
  String get bankName => throw _privateConstructorUsedError;
  String get bankCode => throw _privateConstructorUsedError;
  String get accountNumber => throw _privateConstructorUsedError;
  String get accountName => throw _privateConstructorUsedError;
  bool get isDefault => throw _privateConstructorUsedError;

  /// Serializes this BankAccount to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BankAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BankAccountCopyWith<BankAccount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BankAccountCopyWith<$Res> {
  factory $BankAccountCopyWith(
    BankAccount value,
    $Res Function(BankAccount) then,
  ) = _$BankAccountCopyWithImpl<$Res, BankAccount>;
  @useResult
  $Res call({
    String id,
    String bankName,
    String bankCode,
    String accountNumber,
    String accountName,
    bool isDefault,
  });
}

/// @nodoc
class _$BankAccountCopyWithImpl<$Res, $Val extends BankAccount>
    implements $BankAccountCopyWith<$Res> {
  _$BankAccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BankAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bankName = null,
    Object? bankCode = null,
    Object? accountNumber = null,
    Object? accountName = null,
    Object? isDefault = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            bankName: null == bankName
                ? _value.bankName
                : bankName // ignore: cast_nullable_to_non_nullable
                      as String,
            bankCode: null == bankCode
                ? _value.bankCode
                : bankCode // ignore: cast_nullable_to_non_nullable
                      as String,
            accountNumber: null == accountNumber
                ? _value.accountNumber
                : accountNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            accountName: null == accountName
                ? _value.accountName
                : accountName // ignore: cast_nullable_to_non_nullable
                      as String,
            isDefault: null == isDefault
                ? _value.isDefault
                : isDefault // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BankAccountImplCopyWith<$Res>
    implements $BankAccountCopyWith<$Res> {
  factory _$$BankAccountImplCopyWith(
    _$BankAccountImpl value,
    $Res Function(_$BankAccountImpl) then,
  ) = __$$BankAccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String bankName,
    String bankCode,
    String accountNumber,
    String accountName,
    bool isDefault,
  });
}

/// @nodoc
class __$$BankAccountImplCopyWithImpl<$Res>
    extends _$BankAccountCopyWithImpl<$Res, _$BankAccountImpl>
    implements _$$BankAccountImplCopyWith<$Res> {
  __$$BankAccountImplCopyWithImpl(
    _$BankAccountImpl _value,
    $Res Function(_$BankAccountImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BankAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bankName = null,
    Object? bankCode = null,
    Object? accountNumber = null,
    Object? accountName = null,
    Object? isDefault = null,
  }) {
    return _then(
      _$BankAccountImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        bankName: null == bankName
            ? _value.bankName
            : bankName // ignore: cast_nullable_to_non_nullable
                  as String,
        bankCode: null == bankCode
            ? _value.bankCode
            : bankCode // ignore: cast_nullable_to_non_nullable
                  as String,
        accountNumber: null == accountNumber
            ? _value.accountNumber
            : accountNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        accountName: null == accountName
            ? _value.accountName
            : accountName // ignore: cast_nullable_to_non_nullable
                  as String,
        isDefault: null == isDefault
            ? _value.isDefault
            : isDefault // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BankAccountImpl implements _BankAccount {
  const _$BankAccountImpl({
    required this.id,
    required this.bankName,
    required this.bankCode,
    required this.accountNumber,
    required this.accountName,
    this.isDefault = false,
  });

  factory _$BankAccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$BankAccountImplFromJson(json);

  @override
  final String id;
  @override
  final String bankName;
  @override
  final String bankCode;
  @override
  final String accountNumber;
  @override
  final String accountName;
  @override
  @JsonKey()
  final bool isDefault;

  @override
  String toString() {
    return 'BankAccount(id: $id, bankName: $bankName, bankCode: $bankCode, accountNumber: $accountNumber, accountName: $accountName, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BankAccountImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.bankName, bankName) ||
                other.bankName == bankName) &&
            (identical(other.bankCode, bankCode) ||
                other.bankCode == bankCode) &&
            (identical(other.accountNumber, accountNumber) ||
                other.accountNumber == accountNumber) &&
            (identical(other.accountName, accountName) ||
                other.accountName == accountName) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    bankName,
    bankCode,
    accountNumber,
    accountName,
    isDefault,
  );

  /// Create a copy of BankAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BankAccountImplCopyWith<_$BankAccountImpl> get copyWith =>
      __$$BankAccountImplCopyWithImpl<_$BankAccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BankAccountImplToJson(this);
  }
}

abstract class _BankAccount implements BankAccount {
  const factory _BankAccount({
    required final String id,
    required final String bankName,
    required final String bankCode,
    required final String accountNumber,
    required final String accountName,
    final bool isDefault,
  }) = _$BankAccountImpl;

  factory _BankAccount.fromJson(Map<String, dynamic> json) =
      _$BankAccountImpl.fromJson;

  @override
  String get id;
  @override
  String get bankName;
  @override
  String get bankCode;
  @override
  String get accountNumber;
  @override
  String get accountName;
  @override
  bool get isDefault;

  /// Create a copy of BankAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BankAccountImplCopyWith<_$BankAccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
