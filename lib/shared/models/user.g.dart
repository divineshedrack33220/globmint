// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
  id: json['id'] as String,
  firstName: json['firstName'] as String,
  lastName: json['lastName'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String,
  avatarUrl: json['avatarUrl'] as String?,
  biometricEnabled: json['biometricEnabled'] as bool? ?? false,
  twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  verificationStatus: json['verificationStatus'] as String? ?? 'verified',
);

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
      'phone': instance.phone,
      'avatarUrl': instance.avatarUrl,
      'biometricEnabled': instance.biometricEnabled,
      'twoFactorEnabled': instance.twoFactorEnabled,
      'createdAt': instance.createdAt.toIso8601String(),
      'verificationStatus': instance.verificationStatus,
    };
