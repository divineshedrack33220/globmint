import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Dismissible in-app announcements (maintenance windows, fee changes,
/// product news). Content ships in `assets/announcements.json` so the slot
/// works with zero backend; swapping [loadAll] to fetch from an endpoint is a
/// drop-in change when a CMS exists. Dismissals persist per announcement id.
class AnnouncementService {
  AnnouncementService(this._prefs);

  static const _dismissedKey = 'dismissed_announcements_v1';

  final SharedPreferences _prefs;

  static Future<AnnouncementService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AnnouncementService(prefs);
  }

  Future<List<Announcement>> loadAll() async {
    try {
      final raw = await rootBundle.loadString('assets/announcements.json');
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Announcement.fromJson)
          .where((a) => a.id.isNotEmpty && a.body.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Announcement>> active() async {
    final dismissed = _prefs.getStringList(_dismissedKey) ?? const [];
    final all = await loadAll();
    return all.where((a) => !dismissed.contains(a.id)).toList();
  }

  Future<void> dismiss(String id) async {
    final dismissed = _prefs.getStringList(_dismissedKey) ?? [];
    if (!dismissed.contains(id)) {
      await _prefs.setStringList(_dismissedKey, [...dismissed, id]);
    }
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.actionLabel,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String body;
  final String? actionLabel;
  final String? actionRoute;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        actionLabel: j['action_label'] as String?,
        actionRoute: j['action_route'] as String?,
      );
}
