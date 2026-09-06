import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Samples the NGN-per-USDC rate over time so the homepage can draw a trend
/// sparkline. Samples persist on-device (`SharedPreferences`), at most one per
/// hour, keeping the latest 30. A backend rate-feed can replace this source
/// without touching the chart: it only needs a list of doubles.
class RateSampler {
  RateSampler(this._prefs);

  static const _key = 'rate_history_v1';
  static const _maxSamples = 30;
  static const _minInterval = Duration(hours: 1);

  final SharedPreferences _prefs;

  static Future<RateSampler> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RateSampler(prefs);
  }

  List<double> history() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => (e as Map)['rate'] as num?)
          .whereType<num>()
          .map((n) => n.toDouble())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Records [rate] unless a sample was taken within the last hour or the
  /// value is non-positive. Returns the (possibly unchanged) history.
  List<double> record(double rate) {
    if (rate <= 0) return history();
    final points = history().toList();
    if (points.isNotEmpty) {
      final lastAt = _lastSampledAt();
      if (lastAt != null &&
          DateTime.now().difference(lastAt) < _minInterval) {
        return points;
      }
    }
    points.add(rate);
    while (points.length > _maxSamples) {
      points.removeAt(0);
    }
    _prefs.setString(
      _key,
      jsonEncode(points
          .map((r) => {'t': DateTime.now().millisecondsSinceEpoch, 'rate': r})
          .toList()),
    );
    return points;
  }

  DateTime? _lastSampledAt() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List;
      if (decoded.isEmpty) return null;
      final last = decoded.last as Map;
      final t = (last['t'] as num?)?.toInt();
      if (t == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(t);
    } catch (_) {
      return null;
    }
  }
}
