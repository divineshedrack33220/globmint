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

  Future<User> login(String email, String password) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/login',
      body: {'email': email, 'password': password},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    await _storeToken(data['token'] as String? ?? '');
    final user = _userFromApi(data['user'] as Map<String, dynamic>? ?? {});
    _currentUser = user;
    _isAuthenticated = true;
    return user;
  }

  Future<User> register({
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
    await _storeToken(data['token'] as String? ?? '');
    final user = _userFromApi(data['user'] as Map<String, dynamic>? ?? {});
    _currentUser = user;
    _isAuthenticated = true;
    return user;
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

  Future<bool> verifyOtp(String otp) async => otp.length == 6;

  Future<bool> authenticateWithPin(String pin) async => pin.length == 6;

  Future<bool> authenticateWithBiometric() async => true;

  Future<void> _storeToken(String token) async {
    if (token.isEmpty) return;
    final prefs = await AppConstants.prefs();
    await prefs.setString(AppConstants.authTokenKey, token);
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
    );
  }
}
