import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/core/utils/formatters.dart';

void main() {
  group('CurrencyFormatter.vaultUsdc', () {
    test('parses the numeric lead of a vault balance string', () {
      expect(CurrencyFormatter.vaultUsdc('8.000000 USDC'), 8.0);
      expect(CurrencyFormatter.vaultUsdc('  1234.500000 USDC'), 1234.5);
    });

    test('returns 0 for empty or malformed input', () {
      expect(CurrencyFormatter.vaultUsdc(''), 0);
      expect(CurrencyFormatter.vaultUsdc('USDC'), 0);
      expect(CurrencyFormatter.vaultUsdc('abc 5 USDC'), 0);
    });

    test('handles plain numeric strings', () {
      expect(CurrencyFormatter.vaultUsdc('0'), 0);
      expect(CurrencyFormatter.vaultUsdc('42'), 42);
    });
  });

  group('CurrencyFormatter.formatting', () {
    test('ngn formats with naira symbol and two decimals', () {
      expect(CurrencyFormatter.ngn(123456.789), '₦123,456.79');
    });

    test('ngnWithSign keeps sign outside the format', () {
      expect(CurrencyFormatter.ngnWithSign(-50), '-₦50.00');
    });
  });
}