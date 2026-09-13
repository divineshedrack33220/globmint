import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import 'api_client.dart';

/// Real backend-backed auth service. It stores the returned session token in
/// SharedPreferences (key [AppConstants.authTokenKey]) for use by the shared
/// [ApiClient] on subsequent authenticated calls.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

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
    return user;
  }

  /// Changes the account password after verifying the current one. All other
  /// device sessions are revoked by the backend; this session stays valid.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '${AppConstants.apiV1Prefix}/auth/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
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
    _currentUser = null;
    _isAuthenticated = false;
    final prefs = await AppConstants.prefs();
    await prefs.remove(AppConstants.authTokenKey);
  }

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
    final prefs = await AppConstants.prefs();
    await prefs.setString(AppConstants.authTokenKey, token);
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
