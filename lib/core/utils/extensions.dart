extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get capitalizeWords {
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  String get initials {
    final trimmed = trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String maskAccount() {
    if (length <= 4) return this;
    return '•••• ${substring(length - 4)}';
  }

  String maskEmail() {
    final parts = split('@');
    if (parts.length != 2) return this;
    final emailName = parts[0];
    final domain = parts[1];
    if (emailName.length <= 2) return '•@$domain';
    return '${emailName[0]}${'•' * (emailName.length - 2)}${emailName[emailName.length - 1]}@$domain';
  }

  String maskPhone() {
    final digits = replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 7) return this;
    return '${digits.substring(0, 3)}•••${digits.substring(digits.length - 3)}';
  }
}

extension DoubleExtensions on double {
  String get toFormattedString {
    final parts = toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decimalPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '$buffer.$decimalPart';
  }
}

extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    return now.difference(this).inDays < 7;
  }
}
