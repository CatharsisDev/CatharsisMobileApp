import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/duo_session.dart';
import '../../provider/auth_provider.dart';
import '../../provider/duo_provider.dart';
import '../../provider/theme_provider.dart';
import 'duo_summary_page.dart';

class DuoPastSessionsPage extends ConsumerWidget {
  const DuoPastSessionsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor = customTheme?.fontColor ??
        appTheme.textTheme.bodyMedium?.color ??
        Colors.black87;
    final accentColor =
        customTheme?.preferenceButtonColor ?? appTheme.primaryColor;

    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final sessionsAsync = ref.watch(duoPastSessionsProvider(user.uid));

    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: fontColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Past Sessions',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: sessionsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: accentColor),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 48, color: fontColor.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'Couldn\'t load sessions.\nCheck your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor.withOpacity(0.6),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 64, color: accentColor.withOpacity(0.35)),
                    const SizedBox(height: 20),
                    Text(
                      'No past sessions yet',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: fontColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a duo session and your history will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: fontColor.withOpacity(0.5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final session = sessions[i];
              final isHost = session.hostUid == user.uid;
              final partnerName =
                  isHost ? (session.guestName ?? 'Partner') : session.hostName;
              final total = session.cards.length;
              final matched = session.matchedCards.length;
              final differed = session.splitCards.length;
              final pct =
                  total > 0 ? ((matched / total) * 100).round() : 0;

              return _SessionTile(
                session: session,
                partnerName: partnerName,
                matched: matched,
                differed: differed,
                total: total,
                matchPercent: pct,
                fontColor: fontColor,
                accentColor: accentColor,
                cardColor: appTheme.cardColor,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DuoSummaryPage(
                      sessionCode: session.sessionCode,
                      isHostOverride: isHost,
                    ),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── Session tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final DuoSession session;
  final String partnerName;
  final int matched;
  final int differed;
  final int total;
  final int matchPercent;
  final Color fontColor;
  final Color accentColor;
  final Color cardColor;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.partnerName,
    required this.matched,
    required this.differed,
    required this.total,
    required this.matchPercent,
    required this.fontColor,
    required this.accentColor,
    required this.cardColor,
    required this.onTap,
  });

  Color get _rateColor {
    if (matchPercent >= 70) return const Color(0xFF4CAF50);
    if (matchPercent >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(session.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Match rate circle ─────────────────────────────────────────
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _rateColor.withOpacity(0.1),
                border: Border.all(color: _rateColor.withOpacity(0.35), width: 2),
              ),
              child: Center(
                child: Text(
                  '$matchPercent%',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: _rateColor,
                    fontWeight: FontWeight.w800,
                    fontSize: matchPercent >= 100 ? 13 : 15,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── Middle content ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Partner name + date
                  Row(
                    children: [
                      const Icon(Icons.people_rounded,
                          size: 14, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'with $partnerName',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: fontColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: fontColor.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.favorite_rounded,
                        label: '$matched connected',
                        color: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.compare_arrows_rounded,
                        label: '$differed differed',
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$total questions',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: fontColor.withOpacity(0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // ── Chevron ───────────────────────────────────────────────────
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: fontColor.withOpacity(0.3), size: 22),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Runtime',
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
