// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'beneficiary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Beneficiary _$BeneficiaryFromJson(Map<String, dynamic> json) {
  return _Beneficiary.fromJson(json);
}

/// @nodoc
mixin _$Beneficiary {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get bank => throw _privateConstructorUsedError;
  String get accountNumber => throw _privateConstructorUsedError;
  bool get isFavorite => throw _privateConstructorUsedError;

  /// Serializes this Beneficiary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Beneficiary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BeneficiaryCopyWith<Beneficiary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BeneficiaryCopyWith<$Res> {
  factory $BeneficiaryCopyWith(
    Beneficiary value,
    $Res Function(Beneficiary) then,
  ) = _$BeneficiaryCopyWithImpl<$Res, Beneficiary>;
  @useResult
  $Res call({
    String id,
    String name,
    String bank,
    String accountNumber,
    bool isFavorite,
  });
}

/// @nodoc
class _$BeneficiaryCopyWithImpl<$Res, $Val extends Beneficiary>
    implements $BeneficiaryCopyWith<$Res> {
  _$BeneficiaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Beneficiary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? bank = null,
    Object? accountNumber = null,
    Object? isFavorite = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            bank: null == bank
                ? _value.bank
                : bank // ignore: cast_nullable_to_non_nullable
                      as String,
            accountNumber: null == accountNumber
                ? _value.accountNumber
                : accountNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            isFavorite: null == isFavorite
                ? _value.isFavorite
                : isFavorite // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BeneficiaryImplCopyWith<$Res>
    implements $BeneficiaryCopyWith<$Res> {
  factory _$$BeneficiaryImplCopyWith(
    _$BeneficiaryImpl value,
    $Res Function(_$BeneficiaryImpl) then,
  ) = __$$BeneficiaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String bank,
    String accountNumber,
    bool isFavorite,
  });
}

/// @nodoc
class __$$BeneficiaryImplCopyWithImpl<$Res>
    extends _$BeneficiaryCopyWithImpl<$Res, _$BeneficiaryImpl>
    implements _$$BeneficiaryImplCopyWith<$Res> {
  __$$BeneficiaryImplCopyWithImpl(
    _$BeneficiaryImpl _value,
    $Res Function(_$BeneficiaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Beneficiary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? bank = null,
    Object? accountNumber = null,
    Object? isFavorite = null,
  }) {
    return _then(
      _$BeneficiaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        bank: null == bank
            ? _value.bank
            : bank // ignore: cast_nullable_to_non_nullable
                  as String,
        accountNumber: null == accountNumber
            ? _value.accountNumber
            : accountNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        isFavorite: null == isFavorite
            ? _value.isFavorite
            : isFavorite // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BeneficiaryImpl implements _Beneficiary {
  const _$BeneficiaryImpl({
    required this.id,
    required this.name,
    required this.bank,
    required this.accountNumber,
    this.isFavorite = false,
  });

  factory _$BeneficiaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$BeneficiaryImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String bank;
  @override
  final String accountNumber;
  @override
  @JsonKey()
  final bool isFavorite;

  @override
  String toString() {
    return 'Beneficiary(id: $id, name: $name, bank: $bank, accountNumber: $accountNumber, isFavorite: $isFavorite)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BeneficiaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.bank, bank) || other.bank == bank) &&
            (identical(other.accountNumber, accountNumber) ||
                other.accountNumber == accountNumber) &&
            (identical(other.isFavorite, isFavorite) ||
                other.isFavorite == isFavorite));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, bank, accountNumber, isFavorite);

  /// Create a copy of Beneficiary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BeneficiaryImplCopyWith<_$BeneficiaryImpl> get copyWith =>
      __$$BeneficiaryImplCopyWithImpl<_$BeneficiaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BeneficiaryImplToJson(this);
  }
}

abstract class _Beneficiary implements Beneficiary {
  const factory _Beneficiary({
    required final String id,
    required final String name,
    required final String bank,
    required final String accountNumber,
    final bool isFavorite,
  }) = _$BeneficiaryImpl;

  factory _Beneficiary.fromJson(Map<String, dynamic> json) =
      _$BeneficiaryImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get bank;
  @override
  String get accountNumber;
  @override
  bool get isFavorite;

  /// Create a copy of Beneficiary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BeneficiaryImplCopyWith<_$BeneficiaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
