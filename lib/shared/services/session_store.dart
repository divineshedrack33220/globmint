import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistence for the account's bearer token.
///
/// Split behind an interface so tests can inject an in-memory store instead
/// of touching platform keychains, and so [ApiClient] (which attaches the
/// token to every request) reads from the same source [AuthService] writes
/// to — there is exactly one copy of the token on device.
///
/// The token itself is never logged, printed, or rendered; only non-secret
/// metadata (the remembered login email) shares the store.
abstract class SessionStore {
  /// The current bearer token, or null when signed out.
  Future<String?> readToken();

  Future<void> writeToken(String token);

  /// Deletes the stored token. When [expected] is given the deletion is a
  /// compare-and-clear: if a *different* token is currently stored (a newer
  /// session took over), the call is a no-op so a stale 401 can never sign
  /// out a fresh login.
  Future<void> clearToken({String? expected});

  /// Last-known account email, remembered locally so the unlock screen's
  /// password fallback can pre-fill the login form. Not secret.
  Future<String?> readEmail();

  Future<void> writeEmail(String email);
}

/// Keychain/Keystore-backed store used in production (iOS Keychain, Android
/// Keystore, and the WebCrypto-backed web store). Platform calls that fail
/// (e.g. the plugin is missing under `flutter test`) degrade to "no session"
/// instead of crashing the client.
///
/// Every value is mirrored in an in-process cache. The token stays available
/// for the whole app session the moment it is written — requests never wait on
/// platform I/O for authorization, and a login is instantly visible to every
/// later read even if the underlying store misbehaves (notably WebCrypto /
/// IndexedDB failures in some browsers). Secure storage remains the
/// persistence layer; the mirror is the runtime source of truth.
class SecureSessionStore implements SessionStore {
  SecureSessionStore();

  static const _tokenKey = 'globmint.session_token';
  static const _emailKey = 'globmint.session_email';

  static const _storage = FlutterSecureStorage();

  String? _cachedToken;
  String? _cachedEmail;

  @override
  Future<String?> readToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      final token = await _storage.read(key: _tokenKey);
      _cachedToken = (token == null || token.isEmpty) ? null : token;
    } on MissingPluginException {
      _cachedToken = null;
    } on PlatformException {
      _cachedToken = null;
    }
    return _cachedToken;
  }

  @override
  Future<void> writeToken(String token) async {
    if (token.isEmpty) return;
    _cachedToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on MissingPluginException {
      // No platform store available (tests/web without the plugin): keep the
      // session in memory only rather than failing the whole login.
    } on PlatformException {
      // Same degradation.
    }
  }

  @override
  Future<void> clearToken({String? expected}) async {
    if (expected != null &&
        _cachedToken != null &&
        _cachedToken != expected) {
      return;
    }
    _cachedToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } on MissingPluginException {
      // Nothing persisted on this platform.
    } on PlatformException {
      // Ignore: the in-memory state is still cleared by the caller.
    }
  }

  @override
  Future<String?> readEmail() async {
    if (_cachedEmail != null) return _cachedEmail;
    try {
      final email = await _storage.read(key: _emailKey);
      _cachedEmail = (email == null || email.isEmpty) ? null : email;
    } on MissingPluginException {
      _cachedEmail = null;
    } on PlatformException {
      _cachedEmail = null;
    }
    return _cachedEmail;
  }

  @override
  Future<void> writeEmail(String email) async {
    if (email.isEmpty) return;
    _cachedEmail = email;
    try {
      await _storage.write(key: _emailKey, value: email);
    } on MissingPluginException {
      // Non-fatal: the email is only a convenience pre-fill.
    } on PlatformException {
      // Non-fatal.
    }
  }
}

/// In-memory store for tests (and any process where secure storage is not
/// available). Mirrors [SecureSessionStore] semantics exactly.
class MemorySessionStore implements SessionStore {
  MemorySessionStore({String? token, String? email}) {
    _token = token;
    _email = email;
  }

  String? _token;
  String? _email;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token.isEmpty ? null : token;
  }

  @override
  Future<void> clearToken({String? expected}) async {
    if (expected != null && _token != null && _token != expected) return;
    _token = null;
  }

  @override
  Future<String?> readEmail() async => _email;

  @override
  Future<void> writeEmail(String email) async {
    _email = email.isEmpty ? null : email;
  }
}