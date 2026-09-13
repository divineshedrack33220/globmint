import 'package:flutter/foundation.dart';

/// App-wide connectivity signal, independent of any platform plugin.
///
/// Transport-level outcomes from the live HTTP [ApiClient] and the SSE
/// [EventsServer] feed feed into a single [online] flag: a successful
/// response (or connected SSE stream) means online, a transport failure
/// flips it to offline. Widgets (e.g. the offline banner) watch it to show a
/// "no internet" state instead of silently frozen data.
class ConnectivityService extends ChangeNotifier {
  bool _online = true;

  bool get online => _online;

  /// Marks the connection as reachable. No-op while already online.
  void reportSuccess() {
    if (_online) return;
    _online = true;
    notifyListeners();
  }

  /// Marks the connection as unreachable. No-op while already offline.
  void reportFailure() {
    if (!_online) return;
    _online = false;
    notifyListeners();
  }
}
