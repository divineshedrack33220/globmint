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
}
