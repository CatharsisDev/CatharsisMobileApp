import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/announcement.dart';
import '../../provider/announcements_provider.dart';
import '../../provider/theme_provider.dart';
import '../../components/announcement_popup.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final fontColor = customTheme?.fontColor ??
        theme.textTheme.bodyMedium?.color ??
        Colors.black87;
    final accentColor =
        customTheme?.preferenceButtonColor ?? theme.primaryColor;
    final seenAsync = ref.watch(seenAnnouncementIdsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: fontColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'What\'s New',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          // Mark all read
          seenAsync.maybeWhen(
            data: (seen) {
              final hasUnseen =
                  kAnnouncements.any((a) => !seen.contains(a.id));
              if (!hasUnseen) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await ref
                      .read(announcementsServiceProvider)
                      .markAllSeen();
                  ref.invalidate(seenAnnouncementIdsProvider);
                  ref.invalidate(unseenAnnouncementCountProvider);
                },
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: accentColor,
                    fontSize: 13,
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: seenAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: accentColor)),
        error: (e, _) => Center(
          child: Text('Could not load',
              style: TextStyle(color: fontColor.withOpacity(0.5))),
        ),
        data: (seen) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: kAnnouncements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final a = kAnnouncements[i];
            final isRead = seen.contains(a.id);
            return _AnnouncementTile(
              announcement: a,
              isRead: isRead,
              fontColor: fontColor,
              accentColor: accentColor,
              cardColor: theme.cardColor,
              onTap: () => showAnnouncementPopup(context, ref, a),
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;
  final bool isRead;
  final Color fontColor;
  final Color accentColor;
  final Color cardColor;
  final VoidCallback onTap;

  const _AnnouncementTile({
    required this.announcement,
    required this.isRead,
    required this.fontColor,
    required this.accentColor,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(announcement.date);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emoji circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                announcement.emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: fontColor,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 12,
                          color: fontColor.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcement.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 13,
                      color: fontColor.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Unread dot or chevron
            if (!isRead)
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: fontColor.withOpacity(0.25), size: 20),
          ],
        ),
      ),
    );
  }
}
