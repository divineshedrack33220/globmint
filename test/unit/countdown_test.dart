import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/core/utils/countdown.dart';

void main() {
  test('formatCountdown renders days, hours, minutes, seconds', () {
    expect(formatCountdown(const Duration(days: 2, hours: 3)), '2d 3h');
    expect(formatCountdown(const Duration(hours: 5, minutes: 7)), '5h 7m');
    expect(formatCountdown(const Duration(minutes: 9, seconds: 4)), '9m 4s');
    expect(formatCountdown(const Duration(seconds: 45)), '45s');
  });

  test('formatCountdown reports due locks as releasing', () {
    expect(formatCountdown(Duration.zero), 'releasing…');
    expect(formatCountdown(const Duration(seconds: -30)), 'releasing…');
  });

  test('formatAge describes data freshness', () {
    final now = DateTime.now();
    expect(formatAge(now), 'just now');
    expect(formatAge(now.subtract(const Duration(seconds: 45))), '45s ago');
    expect(formatAge(now.subtract(const Duration(minutes: 5))), '5m ago');
    expect(formatAge(now.subtract(const Duration(hours: 2))), '2h ago');
  });
}
