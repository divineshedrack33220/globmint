import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:globe_mint/shared/services/rate_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('record keeps the latest samples up to the cap', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sampler = RateSampler(prefs);

    expect(sampler.history(), isEmpty);
    expect(sampler.record(0), isEmpty);
    expect(sampler.record(-5), isEmpty);

    final points = sampler.record(1604.5);
    expect(points, [1604.5]);

    // A second sample within the hour is throttled away.
    expect(sampler.record(1605.0), [1604.5]);

    // Reloading from disk preserves history.
    expect(RateSampler(prefs).history(), [1604.5]);
  });
}
