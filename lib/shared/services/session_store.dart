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

  Future<void> clearToken();

  /// Last-known account email, remembered locally so the unlock screen's
  /// password fallback can pre-fill the login form. Not secret.
  Future<String?> readEmail();

  Future<void> writeEmail(String email);
}

/// Keychain/Keystore-backed store used in production (iOS Keychain, Android
/// Keystore, and the WebCrypto-backed web store). Platform calls that fail
/// (e.g. the plugin is missing under `flutter test`) degrade to "no session"
/// instead of crashing the client.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore();

  static const _tokenKey = 'globmint.session_token';
  static const _emailKey = 'globmint.session_email';

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> readToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      return (token == null || token.isEmpty) ? null : token;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> writeToken(String token) async {
    if (token.isEmpty) return;
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
  Future<void> clearToken() async {
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
    try {
      final email = await _storage.read(key: _emailKey);
      return (email == null || email.isEmpty) ? null : email;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> writeEmail(String email) async {
    if (email.isEmpty) return;
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
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readEmail() async => _email;

  @override
  Future<void> writeEmail(String email) async {
    _email = email.isEmpty ? null : email;
  }
}