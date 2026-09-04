// Core app-wide constants and shared backend configuration.

import 'package:shared_preferences/shared_preferences.dart';

abstract final class AppConstants {
  static const String appName = 'Globe Mint';
  static const String appTagline = 'Your digital savings vault';

  static const double minDeposit = 1000;
  static const double maxDeposit = 5000000;
  static const double minWithdrawal = 1000;
  static const double maxWithdrawal = 5000000;

  static const double conversionFeePercent = 0.5;
  static const int pinLength = 6;
  static const int otpLength = 6;

  static const Duration mockDelay = Duration(milliseconds: 800);
  static const Duration mockLongDelay = Duration(milliseconds: 2000);
  static const Duration rateExpiry = Duration(minutes: 5);

  static const int recentTransactionsLimit = 5;
  static const int transactionsPageSize = 20;

  static const String defaultCurrency = 'NGN';
  static const String savingsCurrency = 'USDT';

  // ---- Backend API ----
  static const String apiV1Prefix = '/api/v1';
  static const String authTokenKey = 'auth_token';

  // Base URL for the Go backend. Platform-aware: the Android emulator reaches
  // the host via 10.0.2.2; web/desktop use localhost. Override at runtime by
  // setting the `--dart-define` value GLOBMINT_API_BASE_URL.
  static const String apiBaseUrl = String.fromEnvironment(
    'GLOBMINT_API_BASE_URL',
    defaultValue: '',
  );

  /// SharedPreferences accessor (kept here so services can persist the auth
  /// token without importing the package in many places).
  static Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  /// Resolves the effective base URL using the provided platform loopback.
  /// When [overridden] is non-empty it wins; otherwise emulator vs. host.
  static String baseApiUrl({String override = ''}) {
    if (override.isNotEmpty) return override;
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;
    // Default to localhost; the Android emulator case is handled by callers
    // that pass the emulator loopback.
    return 'http://localhost:8081';
  }

}
