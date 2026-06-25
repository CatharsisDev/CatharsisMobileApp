import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/announcements_service.dart';
import '../models/announcement.dart';

final announcementsServiceProvider = Provider<AnnouncementsService>(
  (_) => AnnouncementsService(),
);

/// Resolves to the set of seen announcement IDs.
final seenAnnouncementIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(announcementsServiceProvider).seenIds();
});

/// Number of unread announcements (used for badge).
final unseenAnnouncementCountProvider = FutureProvider<int>((ref) async {
  final seen = await ref.watch(seenAnnouncementIdsProvider.future);
  return kAnnouncements.where((a) => !seen.contains(a.id)).length;
});
