abstract final class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return 'Enter a valid phone number';
    return null;
  }

  static String? pin(String? value) {
    if (value == null || value.isEmpty) return 'PIN is required';
    if (value.length != 6) return 'PIN must be 6 digits';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return 'PIN must contain only numbers';
    return null;
  }

  static String? confirmPassword(String? value, String pin) {
    if (value == null || value.isEmpty) return 'Please confirm your PIN';
    if (value != pin) return 'PINs do not match';
    return null;
  }

  static String? amount(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than zero';
    if (min != null && parsed < min) return 'Minimum amount is ₦${min.toStringAsFixed(0)}';
    if (max != null && parsed > max) return 'Maximum amount is ₦${max.toStringAsFixed(0)}';
    return null;
  }

  static String? bankAccount(String? value) {
    if (value == null || value.isEmpty) return 'Account number is required';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 10) return 'Account number must be 10 digits';
    return null;
  }

  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.length < min) {
      return '${fieldName ?? 'This field'} must be at least $min characters';
    }
    return null;
  }
}
