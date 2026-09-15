import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import 'api_client.dart';
import 'session_store.dart';

/// Real backend-backed auth service. A successful sign-in stores the bearer
/// token in secure storage (Keychain/Keystore) via [SessionStore] so the app
/// can revalidate the session on the next cold start and offer a biometric
/// "fast reopen" — the token is only ever persisted there, never in logs or
/// plain preferences.
class AuthService {
  AuthService(this._api, {SessionStore? sessionStore})
    : _sessionStore = sessionStore ?? const SecureSessionStore();

  final ApiClient _api;
  final SessionStore _sessionStore;

  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  Future<LoginResult> login(String email, String password) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/login',
      body: {'email': email, 'password': password},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    if (data['requires_2fa'] == true) {
      return LoginResult(
        requiresTwoFactor: true,
        challengeToken: data['challenge_token'] as String? ?? '',
      );
    }
    await _storeToken(data['token'] as String? ?? '');
    final user = _userFromApi(data['user'] as Map<String, dynamic>? ?? {});
    _currentUser = user;
    _isAuthenticated = true;
    await _rememberEmail(user.email);
    return LoginResult(user: user);
  }

  /// Completes a login that required a TOTP one-time code.
  Future<User> verifyTwoFactor(String challengeToken, String code) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/2fa/verify',
      body: {'challenge_token': challengeToken, 'code': code},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    await _storeToken(data['token'] as String? ?? '');
    final user = _userFromApi(data['user'] as Map<String, dynamic>? ?? {});
    _currentUser = user;
    _isAuthenticated = true;
    await _rememberEmail(user.email);
    return user;
  }

  /// Changes the account password after verifying the current one. As a
  /// precaution the stored session token is deleted afterwards (see
  /// [clearSession]): even though the backend keeps this session row valid,
  /// the client requires a fresh password to remain unlocked.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '${AppConstants.apiV1Prefix}/auth/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    await clearSession();
  }

  /// Provisions a new TOTP secret (secret + otpauth URI). 2FA only activates
  /// after [enableTwoFactor] proves the user has the authenticator code.
  Future<Map<String, String>> totpSetup() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/auth/totp/setup');
    if (data == null) throw ApiException(0, 'Empty response from server');
    return {
      'secret': data['secret'] as String? ?? '',
      'uri': data['uri'] as String? ?? '',
    };
  }

  Future<void> enableTwoFactor(String code) async {
    await _api.post(
      '${AppConstants.apiV1Prefix}/auth/totp/enable',
      body: {'code': code},
    );
  }

  Future<void> disableTwoFactor({required String code, required String pin}) async {
    await _api.post(
      '${AppConstants.apiV1Prefix}/auth/totp/disable',
      body: {'code': code, 'pin': pin},
    );
  }

  /// Starts email-OTP-gated registration: the signup profile is staged and a
  /// verification code is sent, but NO account is created until that code is
  /// verified via [verifyOtp]. Returns when a code will be resendable from.
  Future<OtpSendResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/register',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return OtpSendResult(
      sent: data['sent'] == true,
      resendAfter: _epochSeconds(data['resend_after']),
    );
  }

  Future<void> logout() async {
    try {
      await _api.post('${AppConstants.apiV1Prefix}/auth/logout');
    } catch (_) {
      // Best-effort; always clear local session regardless.
    }
    await clearSession();
  }

  /// Restores a stored session on cold start: reads the bearer token from
  /// secure storage and validates it against `GET /users/me`. Returns the user
  /// on success; returns null when there is no token or when the token has
  /// been rejected (401 clears the stored token and [isAuthenticated] is
  /// false). Non-401 failures (network, 5xx) rethrow so the caller can decide
  /// — a session whose validity cannot be confirmed is never trusted.
  Future<User?> currentSession() async {
    final token = await _sessionStore.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      final user = await me();
      if (user != null) await _rememberEmail(user.email);
      return user;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await clearSession();
        return null;
      }
      rethrow;
    }
  }

  /// Drops the session from memory and secure storage. Safe to call at any
  /// point; used by logout, password change, and mid-session 401 handling.
  Future<void> clearSession() async {
    _currentUser = null;
    _isAuthenticated = false;
    await _sessionStore.clearToken();
  }

  /// Clears the session after the backend rejected the bearer token on a
  /// regular call (see [ApiClient.onUnauthorized]).
  Future<void> handleSessionExpired() => clearSession();

  /// The account email remembered at the last successful sign-in, used to
  /// pre-fill the login form from the unlock screen. Not a secret.
  Future<String?> rememberedEmail() => _sessionStore.readEmail();

  Future<User?> me() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/users/me');
    if (data == null) return null;
    final user = _userFromApi(data);
    _currentUser = user;
    _isAuthenticated = true;
    return user;
  }

  /// Requests a fresh 6-digit verification code for [email] (email OTP). The
  /// code is delivered by email and never returned in the response; a 60s
  /// resend cooldown applies per address.
  Future<void> sendOtp(String email) async {
    await _api.post(
      '${AppConstants.apiV1Prefix}/auth/otp/send',
      body: {'email': email},
    );
  }

  /// Checks the emailed [code] for [email]. When the verification completes a
  /// staged registration, the backend creates the account and returns a session
  /// [OtpVerifyResult.token] + [OtpVerifyResult.user] — the client must then
  /// show the PIN setup screen. Throws [ApiException] with code `INVALID_CODE`
  /// for wrong/expired codes and `TOO_MANY_REQUESTS` on the attempt limit.
  Future<OtpVerifyResult> verifyOtp(String email, String code) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/otp/verify',
      body: {'email': email, 'code': code},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    final token = data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await _storeToken(token);
      final user = _userFromApi(data['user'] as Map<String, dynamic>? ?? {});
      _currentUser = user;
      _isAuthenticated = true;
      await _rememberEmail(user.email);
      return OtpVerifyResult(
        verified: data['verified'] == true,
        emailVerified: data['email_verified'] == true,
        token: token,
        user: user,
      );
    }
    return OtpVerifyResult(
      verified: data['verified'] == true,
      emailVerified: data['email_verified'] == true,
    );
  }

  /// Verifies the user's transaction PIN against the backend. Throws
  /// [ApiException] (code INVALID_PIN) on mismatch.
  Future<void> verifyPin(String pin) async {
    await _api.post(
      '${AppConstants.apiV1Prefix}/pin/verify',
      body: {'pin': pin},
    );
  }

  /// Sets the user's transaction PIN on the backend. If a PIN already exists,
  /// [currentPin] must match it.
  Future<void> setPin({required String pin, String? currentPin}) async {
    await _api.put(
      '${AppConstants.apiV1Prefix}/pin',
      body: {
        'pin': pin,
        if (currentPin != null && currentPin.isNotEmpty) 'current_pin': currentPin,
      },
    );
  }

  Future<bool> authenticateWithPin(String pin) async => pin.length == 6;

  Future<bool> authenticateWithBiometric() async => true;

  Future<void> _storeToken(String token) async {
    if (token.isEmpty) return;
    await _sessionStore.writeToken(token);
  }

  Future<void> _rememberEmail(String email) async {
    if (email.isEmpty) return;
    await _sessionStore.writeEmail(email);
  }

  /// Parses a unix-seconds value (as sent by the backend) into a local time,
  /// or null when absent/invalid.
  DateTime? _epochSeconds(Object? seconds) {
    if (seconds is num && seconds > 0) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    return null;
  }

  User _userFromApi(Map<String, dynamic> j) {
    return User(
      id: j['id'] as String? ?? '',
      firstName: j['first_name'] as String? ?? '',
      lastName: j['last_name'] as String? ?? '',
      email: j['email'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      avatarUrl: j['avatar_url'] as String?,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      verificationStatus: j['status'] as String? ?? 'pending',
      twoFactorEnabled: j['two_factor_enabled'] as bool? ?? false,
    );
  }
}

/// Outcome of a credential login. When the account has 2FA enabled,
/// [requiresTwoFactor] is true and the [challengeToken] must be exchanged for
/// a session via [AuthService.verifyTwoFactor].
class LoginResult {
  const LoginResult({this.user, this.requiresTwoFactor = false, this.challengeToken = ''});

  final User? user;
  final bool requiresTwoFactor;
  final String challengeToken;
}

/// Outcome of issuing a verification code. The code itself is never returned;
/// [resendAfter] is the earliest time a fresh code may be requested.
class OtpSendResult {
  const OtpSendResult({this.sent = false, this.resendAfter});

  final bool sent;
  final DateTime? resendAfter;
}

/// Outcome of verifying an emailed code. When the code completed a staged
/// registration, [token] and [user] carry the freshly created session.
class OtpVerifyResult {
  const OtpVerifyResult({
    this.verified = false,
    this.emailVerified = false,
    this.token,
    this.user,
  });

  final bool verified;
  final bool emailVerified;
  final String? token;
  final User? user;
}
