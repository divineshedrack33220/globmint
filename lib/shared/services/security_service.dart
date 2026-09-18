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

  /// Fetches the user's security-activity feed, paged from the backend. The
  /// response carries the total so clients can render "X more" / load-more.
  Future<({List<SecurityEvent> items, int total, bool hasMore})> getSecurityEvents({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _api.get(
      '${AppConstants.apiV1Prefix}/security-events'
      '?limit=$limit&offset=$offset',
    );
    final list = ((data?['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final items = list.map(_eventFromApi).toList();
    final total = (data?['total'] as num?)?.toInt() ?? items.length;
    final hasMore = offset + items.length < total;
    return (items: items, total: total, hasMore: hasMore);
  }

  /// Reads the user's email-alert preferences (new-signin + failed-login).
  Future<SecurityPrefs> getSecurityPrefs() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/security/prefs');
    return SecurityPrefs(
      notifyNewSignin: (data?['notify_new_signin'] as bool?) ?? true,
      notifyFailedLogin: (data?['notify_failed_login'] as bool?) ?? true,
    );
  }

  /// Persists the user's email-alert preferences.
  Future<void> updateSecurityPrefs({
    bool? notifyNewSignin,
    bool? notifyFailedLogin,
  }) async {
    await _api.put(
      '${AppConstants.apiV1Prefix}/security/prefs',
      body: {
        'notify_new_signin': ?notifyNewSignin,
        'notify_failed_login': ?notifyFailedLogin,
      },
    );
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
