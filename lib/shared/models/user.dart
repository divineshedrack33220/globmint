import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? avatarUrl,
    @Default(false) bool biometricEnabled,
    @Default(false) bool twoFactorEnabled,
    required DateTime createdAt,
    @Default('verified') String verificationStatus,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

extension UserExtensions on User {
  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();
}
