import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/duo_session.dart';
import '../../provider/duo_provider.dart';
import '../../provider/theme_provider.dart';
import '../../services/duo_session_service.dart';

/// Returns a visible accent color for duo mode.
/// Dark theme's primaryColor equals the background — use purple instead.
Color _duoAccent(ThemeData t) {
  if (t.brightness == Brightness.dark) return const Color(0xFFBE89FF);
  return t.primaryColor;
}

class DuoSummaryPage extends ConsumerStatefulWidget {
  final String sessionCode;
  const DuoSummaryPage({Key? key, required this.sessionCode}) : super(key: key);

  @override
  ConsumerState<DuoSummaryPage> createState() => _DuoSummaryPageState();
}

class _DuoSummaryPageState extends ConsumerState<DuoSummaryPage> {
  final Set<int> _savingIndices = {};
  final Map<int, TextEditingController> _controllers = {};

  bool get _isHost => ref.read(duoIsHostProvider);

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(int index, String initialText) {
    return _controllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialText),
    );
  }

  Future<void> _saveReflection(int cardIndex, String text) async {
    if (_savingIndices.contains(cardIndex)) return;
    setState(() => _savingIndices.add(cardIndex));
    try {
      await DuoSessionService.saveReflection(
        code: widget.sessionCode,
        cardIndex: cardIndex,
        isHost: _isHost,
        text: text,
      );
    } finally {
      if (mounted) setState(() => _savingIndices.remove(cardIndex));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appThemeEarly = Theme.of(context);
    final sessionAsync =
        ref.watch(duoSessionStreamProvider(widget.sessionCode));

    return sessionAsync.when(
      loading: () => Scaffold(
        backgroundColor: appThemeEarly.scaffoldBackgroundColor,
        body: Center(
            child: CircularProgressIndicator(color: _duoAccent(appThemeEarly))),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: appThemeEarly.scaffoldBackgroundColor,
        body: Center(child: Text('Error: $e')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            backgroundColor: appThemeEarly.scaffoldBackgroundColor,
            body: const Center(child: Text('Session not found.')),
          );
        }

        final appTheme = Theme.of(context);
        final customTheme = appTheme.extension<CustomThemeExtension>();
        final fontColor = customTheme?.fontColor ??
            appTheme.textTheme.bodyMedium?.color ??
            Colors.black87;
        final accentColor = _duoAccent(appTheme);

        final matched = session.matchedCards;
        final split = session.splitCards;
        final partnerName =
            _isHost ? (session.guestName ?? 'Partner') : session.hostName;
        final myName = _isHost
            ? session.hostName
            : (session.guestName ?? 'You');

        return Scaffold(
          backgroundColor: appTheme.scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: appTheme.scaffoldBackgroundColor,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: Icon(Icons.close_rounded, color: fontColor, size: 24),
                  onPressed: () => context.go('/home'),
                ),
                centerTitle: true,
                title: Text(
                  'Session Summary',
                  style: appTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: fontColor,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatsBanner(
                          matched: matched.length, split: split.length),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // ── Connected cards ─────────────────────────────────────────
              if (matched.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFF4CAF50),
                  label: 'Connected (${matched.length})',
                  fontColor: fontColor,
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final card = matched[i];
                      final globalIdx = session.cards.indexOf(card);
                      final myReflection = _isHost
                          ? card.hostReflection
                          : card.guestReflection;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _MatchedCardTile(
                          card: card,
                          globalIndex: globalIdx,
                          isHost: _isHost,
                          myName: myName,
                          partnerName: partnerName,
                          myReflection: myReflection,
                          isSaving: _savingIndices.contains(globalIdx),
                          controller: _controllerFor(globalIdx, myReflection),
                          onSave: (text) => _saveReflection(globalIdx, text),
                          fontColor: fontColor,
                          cardColor: appTheme.cardColor,
                          primaryColor: accentColor,
                        ),
                      );
                    },
                    childCount: matched.length,
                  ),
                ),
              ],

              // ── Split / differed cards ──────────────────────────────────
              if (split.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.compare_arrows_rounded,
                  color: const Color(0xFFF59E0B),
                  label: 'Different Perspectives (${split.length})',
                  fontColor: fontColor,
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final card = split[i];
                      final globalIdx = session.cards.indexOf(card);
                      final myReflection = _isHost
                          ? card.hostReflection
                          : card.guestReflection;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _SplitCardTile(
                          card: card,
                          globalIndex: globalIdx,
                          isHost: _isHost,
                          myName: myName,
                          partnerName: partnerName,
                          myReflection: myReflection,
                          isSaving: _savingIndices.contains(globalIdx),
                          controller: _controllerFor(globalIdx, myReflection),
                          onSave: (text) => _saveReflection(globalIdx, text),
                          fontColor: fontColor,
                          cardColor: appTheme.cardColor,
                          primaryColor: accentColor,
                        ),
                      );
                    },
                    childCount: split.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }
}

// ── Stats banner ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final int matched;
  final int split;

  const _StatsBanner({required this.matched, required this.split});

  @override
  Widget build(BuildContext context) {
    final primaryColor = _duoAccent(Theme.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Connected',
              value: matched.toString(),
              icon: Icons.favorite_rounded,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _StatItem(
              label: 'Different',
              value: split.toString(),
              icon: Icons.compare_arrows_rounded,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _StatItem(
              label: 'Total',
              value: (matched + split).toString(),
              icon: Icons.grid_view_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Color fontColor;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
    required this.fontColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Connected card tile ───────────────────────────────────────────────────────

class _MatchedCardTile extends StatefulWidget {
  final DuoCard card;
  final int globalIndex;
  final bool isHost;
  final String myName;
  final String partnerName;
  final String myReflection;
  final bool isSaving;
  final TextEditingController controller;
  final void Function(String) onSave;
  final Color fontColor;
  final Color cardColor;
  final Color primaryColor;

  const _MatchedCardTile({
    required this.card,
    required this.globalIndex,
    required this.isHost,
    required this.myName,
    required this.partnerName,
    required this.myReflection,
    required this.isSaving,
    required this.controller,
    required this.onSave,
    required this.fontColor,
    required this.cardColor,
    required this.primaryColor,
  });

  @override
  State<_MatchedCardTile> createState() => _MatchedCardTileState();
}

class _MatchedCardTileState extends State<_MatchedCardTile> {
  // Start collapsed; answers were already written during play
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const matchColor = Color(0xFF4CAF50);
    final partnerReflection = widget.isHost
        ? widget.card.guestReflection
        : widget.card.hostReflection;

    return _CardContainer(
      accentColor: matchColor,
      cardColor: widget.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: matchColor, size: 15),
              const SizedBox(width: 6),
              const Text(
                'Connected',
                style: TextStyle(
                  color: matchColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: widget.fontColor.withOpacity(0.4),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.card.questionText,
            style: TextStyle(
              color: widget.fontColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            if (widget.myReflection.isNotEmpty)
              _ReflectionBubble(
                name: widget.myName,
                text: widget.myReflection,
                primaryColor: widget.primaryColor,
                fontColor: widget.fontColor,
                isMe: true,
              )
            else
              _ReflectionField(
                label: 'Your reflection',
                controller: widget.controller,
                isSaving: widget.isSaving,
                onSave: widget.onSave,
                primaryColor: widget.primaryColor,
                fontColor: widget.fontColor,
                bgColor: widget.cardColor,
              ),
            if (partnerReflection.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ReflectionBubble(
                name: widget.partnerName,
                text: partnerReflection,
                primaryColor: widget.primaryColor,
                fontColor: widget.fontColor,
                isMe: false,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Different perspectives card tile ─────────────────────────────────────────

class _SplitCardTile extends StatefulWidget {
  final DuoCard card;
  final int globalIndex;
  final bool isHost;
  final String myName;
  final String partnerName;
  final String myReflection;
  final bool isSaving;
  final TextEditingController controller;
  final void Function(String) onSave;
  final Color fontColor;
  final Color cardColor;
  final Color primaryColor;

  const _SplitCardTile({
    required this.card,
    required this.globalIndex,
    required this.isHost,
    required this.myName,
    required this.partnerName,
    required this.myReflection,
    required this.isSaving,
    required this.controller,
    required this.onSave,
    required this.fontColor,
    required this.cardColor,
    required this.primaryColor,
  });

  @override
  State<_SplitCardTile> createState() => _SplitCardTileState();
}

class _SplitCardTileState extends State<_SplitCardTile> {
  // Start expanded to invite reading each other's answers
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final myDecision = widget.isHost
        ? widget.card.hostDecision
        : widget.card.guestDecision;
    final partnerDecision = widget.isHost
        ? widget.card.guestDecision
        : widget.card.hostDecision;
    final partnerReflection = widget.isHost
        ? widget.card.guestReflection
        : widget.card.hostReflection;

    return _CardContainer(
      accentColor: const Color(0xFFF59E0B),
      cardColor: widget.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _VoteTag(
                  name: 'You',
                  decision: myDecision,
                  fontColor: widget.fontColor),
              const SizedBox(width: 8),
              _VoteTag(
                  name: widget.partnerName,
                  decision: partnerDecision,
                  fontColor: widget.fontColor),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: widget.fontColor.withOpacity(0.4),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.card.questionText,
            style: TextStyle(
              color: widget.fontColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            if (widget.myReflection.isNotEmpty)
              _ReflectionBubble(
                name: widget.myName,
                text: widget.myReflection,
                primaryColor: widget.primaryColor,
                fontColor: widget.fontColor,
                isMe: true,
              )
            else
              _ReflectionField(
                label: 'Add a reflection…',
                controller: widget.controller,
                isSaving: widget.isSaving,
                onSave: widget.onSave,
                primaryColor: widget.primaryColor,
                fontColor: widget.fontColor,
                bgColor: widget.cardColor,
              ),
            if (partnerReflection.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ReflectionBubble(
                name: widget.partnerName,
                text: partnerReflection,
                primaryColor: widget.primaryColor,
                fontColor: widget.fontColor,
                isMe: false,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Shared subwidgets ─────────────────────────────────────────────────────────

class _CardContainer extends StatelessWidget {
  final Color accentColor;
  final Widget child;
  final Color cardColor;

  const _CardContainer({
    required this.accentColor,
    required this.child,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Shows a player's vote (either new match choice or legacy swipe) as a tag.
class _VoteTag extends StatelessWidget {
  final String name;
  final String? decision; // 'matched'|'differed'|'like'|'pass'|null
  final Color fontColor;

  const _VoteTag(
      {required this.name,
      required this.decision,
      required this.fontColor});

  Color get _color {
    switch (decision) {
      case 'matched':
      case 'like':
        return const Color(0xFF4CAF50);
      case 'differed':
      case 'pass':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData get _icon {
    switch (decision) {
      case 'matched':
      case 'like':
        return Icons.favorite_rounded;
      case 'differed':
        return Icons.compare_arrows_rounded;
      case 'pass':
        return Icons.close_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String get _label {
    switch (decision) {
      case 'matched':
        return 'Matched';
      case 'differed':
        return 'Differed';
      case 'like':
        return 'Liked';
      case 'pass':
        return 'Passed';
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(
            '$name: $_label',
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reflection bubble (read-only) shown in summary tiles.
class _ReflectionBubble extends StatelessWidget {
  final String name;
  final String text;
  final Color primaryColor;
  final Color fontColor;
  final bool isMe;

  const _ReflectionBubble({
    required this.name,
    required this.text,
    required this.primaryColor,
    required this.fontColor,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe
        ? primaryColor.withOpacity(0.08)
        : fontColor.withOpacity(0.05);
    final border = isMe
        ? primaryColor.withOpacity(0.2)
        : fontColor.withOpacity(0.1);
    final nameColor = isMe ? primaryColor : fontColor.withOpacity(0.6);
    final nameIcon =
        isMe ? Icons.edit_rounded : Icons.person_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(nameIcon, size: 13, color: nameColor),
              const SizedBox(width: 5),
              Text(
                name,
                style: TextStyle(
                  color: nameColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style:
                TextStyle(color: fontColor, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ReflectionField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isSaving;
  final void Function(String) onSave;
  final Color primaryColor;
  final Color fontColor;
  final Color bgColor;

  const _ReflectionField({
    required this.label,
    required this.controller,
    required this.isSaving,
    required this.onSave,
    required this.primaryColor,
    required this.fontColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final dimColor = fontColor.withOpacity(0.3);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(color: fontColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: dimColor, fontSize: 14),
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: dimColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: dimColor),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isSaving ? null : () => onSave(controller.text),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSaving ? dimColor : primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isSaving
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded,
                    color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}
