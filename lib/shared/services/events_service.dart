import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Kind of data mutation pushed by the backend over the SSE feed.
enum EventKind { account, vault, transactions, all }

/// A server-pushed change notification from `GET /api/v1/events`.
class UserEvent {
  const UserEvent({required this.type, required this.kind});

  final String type;
  final EventKind kind;

  bool get isConnected => type == 'connected';

  static UserEvent parse(Map<String, dynamic> json) {
    return UserEvent(
      type: (json['type'] as String? ?? 'data.changed'),
      kind: _kindOf(json['kind'] as String? ?? 'all'),
    );
  }

  static EventKind _kindOf(String raw) {
    return switch (raw.toLowerCase()) {
      'account' => EventKind.account,
      'vault' => EventKind.vault,
      'transactions' => EventKind.transactions,
      _ => EventKind.all,
    };
  }
}

/// Streaming client for the backend Server-Sent Events feed at
/// `GET /api/v1/events`. Holds the connection open and automatically
/// reconnects with exponential backoff (1..15s). Emits [UserEvent]s on the
/// broadcast [stream].
class EventsServer {
  EventsServer({String? baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl ?? AppConstants.baseApiUrl(),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  final StreamController<UserEvent> _events =
      StreamController<UserEvent>.broadcast();

  StreamSubscription<String>? _sub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  /// Broadcast stream of server-pushed change notifications.
  Stream<UserEvent> get stream => _events.stream;

  /// Opens the feed and keeps it alive with automatic backoff reconnection
  /// until [close] is called. Safe to call once from a widget lifecycle.
  void connect() {
    if (_disposed) return;
    _open();
  }

  Future<void> _open() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.authTokenKey);
    if (token == null || token.isEmpty) {
      _events.addError(StateError('Not authenticated for SSE'));
      return;
    }

    try {
      final req = http.Request('GET', _uri())
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';
      final res = await _http.send(req);
      if (_disposed) return;
      if (res.statusCode != 200) {
        _scheduleReconnect(1);
        return;
      }
      _listen(res.stream);
    } catch (_) {
      _scheduleReconnect(1);
    }
  }

  void _listen(Stream<List<int>> raw) {
    unawaited(_sub?.cancel());
    _sub = raw
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onError: (_) => _scheduleReconnect(1),
          onDone: () => _scheduleReconnect(1),
        );
  }
  void _handleLine(String line) {
    final trimmed = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
    if (!trimmed.startsWith('data:')) return;
    final data = trimmed.substring(5).trim();
    if (data.isEmpty) return;
    try {
      _events.add(UserEvent.parse(jsonDecode(data) as Map<String, dynamic>));
    } catch (_) {
      // Ignore malformed frames; keepalive comments are non-data and skipped.
    }
  }

  // Exponential backoff: 1, 2, 4, 8, 15, 15, ... seconds.
  void _scheduleReconnect(int seconds) {
    if (_disposed || _reconnectTimer != null) return;
    _reconnectTimer = Timer(
      Duration(seconds: seconds),
      () {
        _reconnectTimer = null;
        if (!_disposed) _open();
      },
    );
  }

  Uri _uri() {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse('$base/api/v1/events');
  }

  /// Stops the feed and releases resources.
  Future<void> close() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _events.close();
  }
}