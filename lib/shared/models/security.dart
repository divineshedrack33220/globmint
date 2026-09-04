import 'package:freezed_annotation/freezed_annotation.dart';

part 'security.freezed.dart';
part 'security.g.dart';

/// A user's active signed-in device (session).
@freezed
class Device with _$Device {
  const factory Device({
    required String id,
    required String name,
    required String detail,
    String? ip,
    @Default(false) bool isCurrent,
    required DateTime lastActiveAt,
    required DateTime createdAt,
  }) = _Device;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}

/// A security-activity event on the user's account.
@freezed
class SecurityEvent with _$SecurityEvent {
  const factory SecurityEvent({
    required String id,
    required String type,
    required String title,
    required String detail,
    required DateTime time,
  }) = _SecurityEvent;

  factory SecurityEvent.fromJson(Map<String, dynamic> json) =>
      _$SecurityEventFromJson(json);
}

/// An in-app inbox notification.
@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String title,
    required String body,
    required DateTime date,
    @Default(false) bool isRead,
    @Default('general') String category,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
