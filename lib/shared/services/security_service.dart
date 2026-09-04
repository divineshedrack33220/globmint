import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed service for devices, security activity, and the in-app
/// notification inbox. Maps snake_case responses into the frontend models.
class SecurityService {
  SecurityService(this._api);

  final ApiClient _api;

  /// Fetches the user's active signed-in devices.
  Future<List<Device>> getDevices() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/devices');
    final list = ((data?['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return list.map(_deviceFromApi).toList();
  }

  Future<void> revokeDevice(String id) async {
    await _api.post('${AppConstants.apiV1Prefix}/devices/$id/revoke');
  }

  Future<void> revokeOtherDevices() async {
    await _api.post('${AppConstants.apiV1Prefix}/devices/revoke-others');
  }

  /// Fetches the user's security-activity feed.
  Future<List<SecurityEvent>> getSecurityEvents() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/security-events');
    final list = ((data?['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return list.map(_eventFromApi).toList();
  }

  /// Fetches the in-app notification inbox and unread count.
  Future<({List<AppNotification> items, int unread})> getNotifications() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/notifications');
    final list = ((data?['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final items = list.map(_notificationFromApi).toList();
    final unread = (data?['unread'] as num?)?.toInt() ?? 0;
    return (items: items, unread: unread);
  }

  Future<void> markNotificationRead(String id) async {
    await _api.post('${AppConstants.apiV1Prefix}/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post('${AppConstants.apiV1Prefix}/notifications/read-all');
  }

  Device _deviceFromApi(Map<String, dynamic> j) {
    return Device(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? 'Device',
      detail: j['detail'] as String? ?? '',
      ip: j['ip'] as String?,
      isCurrent: j['is_current'] as bool? ?? false,
      lastActiveAt: DateTime.tryParse(j['last_active_at'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  SecurityEvent _eventFromApi(Map<String, dynamic> j) {
    return SecurityEvent(
      id: j['id'] as String? ?? '',
      type: j['type'] as String? ?? 'login',
      title: j['title'] as String? ?? '',
      detail: j['detail'] as String? ?? '',
      time: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  AppNotification _notificationFromApi(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      category: j['category'] as String? ?? 'general',
      isRead: j['is_read'] as bool? ?? false,
      date: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
