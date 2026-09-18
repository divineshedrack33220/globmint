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

  factory Device.fromJson(Map<String, dynamic> json) =>
      _$DeviceFromJson(json);
}

@freezed
class SecurityEvent with _$SecurityEvent {
  const factory SecurityEvent({
    required String id,
    required String type,
    required String title,
    required String detail,
    @Default('info') String severity,
    String? ip,
    String? userAgent,
    String? device,
    Map<String, dynamic>? metadata,
    required DateTime time,
  }) = _SecurityEvent;

  factory SecurityEvent.fromJson(Map<String, dynamic> json) =>
      _$SecurityEventFromJson(json);
}

/// The user's email-alert preferences (severity + notification toggles),
/// mirrored from the backend `/security/prefs` surface.
@freezed
class SecurityPrefs with _$SecurityPrefs {
  const factory SecurityPrefs({
    @Default(true) bool notifyNewSignin,
    @Default(true) bool notifyFailedLogin,
  }) = _SecurityPrefs;

  factory SecurityPrefs.fromJson(Map<String, dynamic> json) =>
      _$SecurityPrefsFromJson(json);
}

/// An in-app notification.
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
