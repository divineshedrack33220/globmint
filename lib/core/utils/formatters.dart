import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static final NumberFormat _ngnFormat = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  static final NumberFormat _usdtFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '',
    decimalDigits: 2,
  );

  static final NumberFormat _ngnCompact = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );

  static String ngn(double amount) => _ngnFormat.format(amount);

  static String usdt(double amount) => '${_usdtFormat.format(amount)} USDT';

  static String ngnCompact(double amount) => _ngnCompact.format(amount);

  static String ngnWithSign(double amount) {
    if (amount < 0) return '-${_ngnFormat.format(amount.abs())}';
    return _ngnFormat.format(amount);
  }

  static String percentage(double value) {
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}%';
  }
}

abstract final class DateFormatter {
  static final DateFormat _full = DateFormat('MMM d, yyyy • h:mm a');
  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _dayMonth = DateFormat('MMM d');
  static final DateFormat _relative = DateFormat('MMM d, yyyy');

  static String full(DateTime date) => _full.format(date);
  static String date(DateTime date) => _date.format(date);
  static String time(DateTime date) => _time.format(date);
  static String dayMonth(DateTime date) => _dayMonth.format(date);
  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _relative.format(date);
  }
}

abstract final class PhoneFormatter {
  static String format(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    if (digits.length == 13 && digits.startsWith('234')) {
      return '+234 ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9)}';
    }
    return phone;
  }
}

abstract final class AccountNumberFormatter {
  static String mask(String number) {
    if (number.length <= 4) return number;
    return '•••• ${number.substring(number.length - 4)}';
  }

  static String format(String number) {
    if (number.length != 10) return number;
    return '${number.substring(0, 3)} ${number.substring(3, 6)} ${number.substring(6)}';
  }
}
