import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import 'connectivity.dart';

/// A thin, shared HTTP client for the GlobMint Go backend.
///
/// Responsibilities:
///   - resolves the base URL (host vs. Android-emulator loopback),
///   - attaches the bearer token from SharedPreferences,
///   - attaches an Idempotency-Key header for money-movement calls,
///   - centralizes JSON encode/decode and error handling.
///
/// Business service classes take an [ApiClient] and call [get]/[post]/[put].
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl, this.connectivity})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl();

  final http.Client _http;
  final String _baseUrl;

  /// Online/offline signal updated from transport outcomes (may be null in
  /// tests where connectivity reporting is irrelevant).
  final ConnectivityService? connectivity;

  /// Runs a transport call, flipping the connectivity signal on outcomes.
  Future<http.Response> _run(Future<http.Response> Function() call) async {
    try {
      final res = await call();
      connectivity?.reportSuccess();
      return res;
    } on http.ClientException {
      connectivity?.reportFailure();
      rethrow;
    } on TimeoutException {
      connectivity?.reportFailure();
      rethrow;
    }
  }

  /// Idempotency keys held per endpoint until that call succeeds, so a retry
  /// after a failure reuses the same key and the backend can dedupe the money
  /// movement instead of double-applying it.
  final Map<String, String> _pendingKeys = {};

  /// The resolved server origin, e.g. `http://localhost:8081`.
  String get baseUrl => _baseUrl;

  /// Whether we should use the Android-emulator loopback (10.0.2.2).
  static bool get _isAndroid =>
      const bool.fromEnvironment('GLOBMINT_ANDROID', defaultValue: false);

  static String _defaultBaseUrl() {
    var resolved = AppConstants.baseApiUrl();
    if (resolved.isEmpty && _isAndroid) {
      resolved = 'http://10.0.2.2:8081';
    }
    if (resolved.isEmpty) resolved = 'http://localhost:8081';
    if (resolved.endsWith('/')) {
      resolved = resolved.substring(0, resolved.length - 1);
    }
    return resolved;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p');
  }

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.authTokenKey);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  /// Returns the idempotency key for [path], reusing any key from a previous
  /// failed attempt so money moves aren't duplicated on retry.
  String _idempotencyKeyFor(String path) => _pendingKeys[path] ??= _newKey();

  void _releaseKey(String path) => _pendingKeys.remove(path);

  static String _newKey() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    return 'app-$rnd-${rnd.toRadixString(16)}';
  }

  Future<Map<String, dynamic>?> get(
    String path, {
    bool idempotent = false,
  }) async {
    final key = idempotent ? _idempotencyKeyFor(path) : null;
    final headers = await _headers(idempotencyKey: key);
    final res = await _run(() => _http.get(_uri(path), headers: headers));
    final data = _decode(res);
    if (key != null) _releaseKey(path);
    return data;
  }

  Future<Map<String, dynamic>?> post(
    String path, {
    Map<String, dynamic>? body,
    bool idempotent = false,
  }) async {
    final key = idempotent ? _idempotencyKeyFor(path) : null;
    final headers = await _headers(idempotencyKey: key);
    final res = await _run(
      () => _http.post(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final data = _decode(res);
    if (key != null) _releaseKey(path);
    return data;
  }

  Future<Map<String, dynamic>?> put(
    String path, {
    Map<String, dynamic>? body,
    bool idempotent = false,
  }) async {
    final key = idempotent ? _idempotencyKeyFor(path) : null;
    final headers = await _headers(idempotencyKey: key);
    final res = await _run(
      () => _http.put(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final data = _decode(res);
    if (key != null) _releaseKey(path);
    return data;
  }

  Future<Map<String, dynamic>?> patch(
    String path, {
    Map<String, dynamic>? body,
    bool idempotent = false,
  }) async {
    final key = idempotent ? _idempotencyKeyFor(path) : null;
    final headers = await _headers(idempotencyKey: key);
    final res = await _run(
      () => _http.patch(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final data = _decode(res);
    if (key != null) _releaseKey(path);
    return data;
  }

  Future<Map<String, dynamic>?> delete(
    String path, {
    bool idempotent = false,
  }) async {
    final key = idempotent ? _idempotencyKeyFor(path) : null;
    final headers = await _headers(idempotencyKey: key);
    final res = await _run(() => _http.delete(_uri(path), headers: headers));
    final data = _decode(res);
    if (key != null) _releaseKey(path);
    return data;
  }

  /// Decodes the body and throws [ApiException] on non-2xx responses, surfacing
  /// the backend's stable error message when present.
  Map<String, dynamic>? _decode(http.Response res) {
    Map<String, dynamic>? data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }
    final message =
        data?['message'] as String? ??
        data?['error'] as String? ??
        'Request failed';
    throw ApiException(
      res.statusCode,
      message,
      code: data?['code'] as String? ?? '',
    );
  }
}

/// Raised for non-2xx backend responses. Carries the HTTP status, a
/// user-safe message from the backend error envelope, and the stable error
/// code (e.g. INVALID_PIN) for programmatic handling.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code = ''});
  final int statusCode;
  final String message;
  final String code;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
