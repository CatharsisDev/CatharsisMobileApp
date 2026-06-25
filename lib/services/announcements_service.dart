import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement.dart';

class AnnouncementsService {
  static const _seenKey = 'seen_announcement_ids';

  /// IDs the user has already read.
  Future<Set<String>> seenIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_seenKey) ?? []).toSet();
  }

  /// Mark a single announcement as seen.
  Future<void> markSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = (prefs.getStringList(_seenKey) ?? []).toSet()..add(id);
    await prefs.setStringList(_seenKey, seen.toList());
  }

  /// Mark every announcement as seen.
  Future<void> markAllSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _seenKey,
      kAnnouncements.map((a) => a.id).toList(),
    );
  }

  /// Returns unseen announcements, newest first.
  Future<List<Announcement>> unseenAnnouncements() async {
    final seen = await seenIds();
    return kAnnouncements.where((a) => !seen.contains(a.id)).toList();
  }

  /// How many announcements are still unread.
  Future<int> unseenCount() async => (await unseenAnnouncements()).length;
}
