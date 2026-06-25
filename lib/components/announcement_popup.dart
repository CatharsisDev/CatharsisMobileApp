import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/announcement.dart';
import '../provider/announcements_provider.dart';
import '../provider/theme_provider.dart';

/// Shows a bottom-sheet detail card for a single announcement.
/// Marks it as seen automatically on open.
Future<void> showAnnouncementPopup(
  BuildContext context,
  WidgetRef ref,
  Announcement announcement,
) async {
  // Mark seen immediately so badge updates
  await ref.read(announcementsServiceProvider).markSeen(announcement.id);
  ref.invalidate(seenAnnouncementIdsProvider);
  ref.invalidate(unseenAnnouncementCountProvider);

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AnnouncementSheet(announcement: announcement),
  );
}

class _AnnouncementSheet extends ConsumerWidget {
  final Announcement announcement;
  const _AnnouncementSheet({required this.announcement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final bg = customTheme?.preferenceModalBackgroundColor ?? theme.cardColor;
    final fontColor = customTheme?.fontColor ??
        theme.textTheme.bodyMedium?.color ??
        Colors.black87;
    final accentColor =
        customTheme?.preferenceButtonColor ?? theme.primaryColor;
    final dateStr = DateFormat('MMMM d, yyyy').format(announcement.date);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: fontColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  // Emoji badge
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        announcement.emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    announcement.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: fontColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Date
                  Text(
                    dateStr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 13,
                      color: fontColor.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Divider(color: fontColor.withOpacity(0.1)),
                  const SizedBox(height: 20),

                  // Body
                  Text(
                    announcement.body,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 16,
                      height: 1.65,
                      color: fontColor.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Got it',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: customTheme?.buttonFontColor ?? Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
