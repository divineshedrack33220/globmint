import 'dart:async';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import 'mock_data.dart';

class MockAuthService {
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  Future<User> login(String email, String password) async {
    await Future.delayed(AppConstants.mockDelay);
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Invalid credentials');
    }
    _currentUser = MockData.user;
    _isAuthenticated = true;
    return _currentUser!;
  }

  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await Future.delayed(AppConstants.mockDelay);
    _currentUser = User(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      createdAt: DateTime.now(),
    );
    return _currentUser!;
  }

  Future<bool> verifyOtp(String otp) async {
    await Future.delayed(AppConstants.mockDelay);
    return otp == '123456' || otp.length == 6;
  }

  Future<void> createPin(String pin) async {
    await Future.delayed(AppConstants.mockDelay);
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    _isAuthenticated = false;
  }

  Future<bool> authenticateWithBiometric() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<bool> authenticateWithPin(String pin) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return pin == '123456' || pin.length == 6;
  }
}
