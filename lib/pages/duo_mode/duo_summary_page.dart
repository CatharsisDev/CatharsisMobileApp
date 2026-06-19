import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/duo_session.dart';
import '../../provider/auth_provider.dart';
import '../../provider/duo_provider.dart';
import '../../provider/theme_provider.dart';
import '../../services/duo_session_service.dart';

/// Returns the button accent color for duo mode — mirrors existing app buttons.
Color _duoAccent(ThemeData t) {
  return t.extension<CustomThemeExtension>()?.preferenceButtonColor ?? t.primaryColor;
}

class DuoSummaryPage extends ConsumerStatefulWidget {
  final String sessionCode;
  /// When opened from past-sessions history, pass the correct value here
  /// so the page doesn't rely on the ephemeral duoIsHostProvider.
  final bool? isHostOverride;

  const DuoSummaryPage({
    Key? key,
    required this.sessionCode,
    this.isHostOverride,
  }) : super(key: key);

  @override
  ConsumerState<DuoSummaryPage> createState() => _DuoSummaryPageState();
}

class _DuoSummaryPageState extends ConsumerState<DuoSummaryPage> {
  final Set<int> _savingIndices = {};
  final Map<int, TextEditingController> _controllers = {};

  bool get _isHost => widget.isHostOverride ?? ref.read(duoIsHostProvider);
  String get _myUid => ref.read(authStateProvider).value?.uid ?? '';

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
    final sessionAsync = ref.watch(duoSessionStreamProvider(widget.sessionCode));

    return sessionAsync.when(
      loading: () => Scaffold(
        backgroundColor: appThemeEarly.scaffoldBackgroundColor,
        body: Center(
            child: CircularProgressIndicator(color: _duoAccent(appThemeEarly))),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: appThemeEarly.scaffoldBackgroundColor,
        body: Center(child: Text('Error: $e',
            style: const TextStyle(fontFamily: 'Runtime'))),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            backgroundColor: appThemeEarly.scaffoldBackgroundColor,
            body: const Center(
              child: Text('Session not found.',
                  style: TextStyle(fontFamily: 'Runtime')),
            ),
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
                  style: TextStyle(
                    fontFamily: 'Runtime',
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
                        matched: matched.length,
                        split: split.length,
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // ── Connected cards ────────────────────────────────────────────
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
                      final myReflection = session.isGroupMode
                          ? (card.playerReflections[_myUid] ?? '')
                          : (_isHost ? card.hostReflection : card.guestReflection);
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
                          playerReflections: session.isGroupMode
                              ? card.playerReflections : null,
                          participants: session.isGroupMode
                              ? session.participants : null,
                          myUid: session.isGroupMode ? _myUid : null,
                        ),
                      );
                    },
                    childCount: matched.length,
                  ),
                ),
              ],

              // ── Different perspectives cards ────────────────────────────────
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
                      final myReflection = session.isGroupMode
                          ? (card.playerReflections[_myUid] ?? '')
                          : (_isHost ? card.hostReflection : card.guestReflection);
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
                          playerReflections: session.isGroupMode
                              ? card.playerReflections : null,
                          participants: session.isGroupMode
                              ? session.participants : null,
                          myUid: session.isGroupMode ? _myUid : null,
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
    final total = matched + split;
    // Match rate as a percentage of all cards played
    final matchPercent = total > 0
        ? ((matched / total) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
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
          Container(width: 1, height: 58, color: Colors.white30),
          Expanded(
            child: _StatItem(
              label: 'Different',
              value: split.toString(),
              icon: Icons.compare_arrows_rounded,
            ),
          ),
          Container(width: 1, height: 58, color: Colors.white30),
          // Match rate replaces "Total" — more meaningful stat
          Expanded(
            child: _StatItem(
              label: 'Match Rate',
              value: '$matchPercent%',
              icon: Icons.bar_chart_rounded,
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
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Runtime',
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Runtime',
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
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
                fontFamily: 'Runtime',
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
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
  // Group mode: when non-null, reflections are read from playerReflections.
  final Map<String, String>? playerReflections;
  final Map<String, String>? participants;
  final String? myUid;

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
    this.playerReflections,
    this.participants,
    this.myUid,
  });

  @override
  State<_MatchedCardTile> createState() => _MatchedCardTileState();
}

class _MatchedCardTileState extends State<_MatchedCardTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const matchColor = Color(0xFF4CAF50);
    final isGroupMode = widget.playerReflections != null;

    // 2-player partner reflection (unused in group mode).
    final partnerReflection = isGroupMode
        ? ''
        : (widget.isHost
            ? widget.card.guestReflection
            : widget.card.hostReflection);

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
                  fontFamily: 'Runtime',
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
              fontFamily: 'Runtime',
              color: widget.fontColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            // My reflection
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
            // Group mode: show every other participant's reflection.
            if (isGroupMode) ...[
              for (final entry
                  in (widget.playerReflections ?? {}).entries)
                if (entry.key != widget.myUid && entry.value.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ReflectionBubble(
                    name: widget.participants?[entry.key] ?? 'Player',
                    text: entry.value,
                    primaryColor: widget.primaryColor,
                    fontColor: widget.fontColor,
                    isMe: false,
                  ),
                ],
            ] else ...[
              // 2-player mode: show single partner reflection.
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
        ],
      ),
    );
  }
}

// ── Different perspectives card tile ──────────────────────────────────────────

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
  // Group mode: when non-null, reflections are read from playerReflections.
  final Map<String, String>? playerReflections;
  final Map<String, String>? participants;
  final String? myUid;

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
    this.playerReflections,
    this.participants,
    this.myUid,
  });

  @override
  State<_SplitCardTile> createState() => _SplitCardTileState();
}

class _SplitCardTileState extends State<_SplitCardTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final isGroupMode = widget.playerReflections != null;

    final myDecision = widget.isHost
        ? widget.card.hostDecision
        : widget.card.guestDecision;
    final partnerDecision = widget.isHost
        ? widget.card.guestDecision
        : widget.card.hostDecision;
    final partnerReflection = isGroupMode
        ? ''
        : (widget.isHost
            ? widget.card.guestReflection
            : widget.card.hostReflection);

    return _CardContainer(
      accentColor: const Color(0xFFF59E0B),
      cardColor: widget.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vote tags — wrapped so multiple players never overflow
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (isGroupMode)
                      ...widget.card.playerVotes.entries.map((e) => _VoteTag(
                            name: widget.participants?[e.key] ?? 'Player',
                            decision: e.value,
                            fontColor: widget.fontColor,
                          ))
                    else ...[
                      _VoteTag(
                          name: 'You',
                          decision: myDecision,
                          fontColor: widget.fontColor),
                      _VoteTag(
                          name: widget.partnerName,
                          decision: partnerDecision,
                          fontColor: widget.fontColor),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
              fontFamily: 'Runtime',
              color: widget.fontColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            // My reflection
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
            // Group mode: show every other participant's reflection.
            if (isGroupMode) ...[
              for (final entry
                  in (widget.playerReflections ?? {}).entries)
                if (entry.key != widget.myUid && entry.value.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ReflectionBubble(
                    name: widget.participants?[entry.key] ?? 'Player',
                    text: entry.value,
                    primaryColor: widget.primaryColor,
                    fontColor: widget.fontColor,
                    isMe: false,
                  ),
                ],
            ] else ...[
              // 2-player mode: show single partner reflection.
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
        ],
      ),
    );
  }
}

// ── Shared subwidgets ──────────────────────────────────────────────────────────

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

class _VoteTag extends StatelessWidget {
  final String name;
  final String? decision;
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
              fontFamily: 'Runtime',
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
    final bg = isMe ? primaryColor.withOpacity(0.08) : fontColor.withOpacity(0.05);
    final border = isMe ? primaryColor.withOpacity(0.2) : fontColor.withOpacity(0.1);
    final nameColor = isMe ? primaryColor : fontColor.withOpacity(0.6);
    final nameIcon = isMe ? Icons.edit_rounded : Icons.person_rounded;

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
                  fontFamily: 'Runtime',
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
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor,
              fontSize: 13,
              height: 1.4,
            ),
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
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                fontFamily: 'Runtime',
                color: dimColor,
                fontSize: 14,
              ),
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
