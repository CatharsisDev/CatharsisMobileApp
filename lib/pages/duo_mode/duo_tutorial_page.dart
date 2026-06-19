import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../provider/theme_provider.dart';

const _kTutorialSeenKey = 'duo_tutorial_seen';

/// Returns true if the tutorial has been permanently dismissed.
Future<bool> isDuoTutorialSeen() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kTutorialSeenKey) ?? false;
}

/// Full-screen tutorial page for Duo Mode.
///
/// Pass [onContinue] as the action to perform when the user taps "Let's go!".
/// If [showDontAskAgain] is false the "Don't show again" checkbox is hidden
/// (used when the user opens the tutorial via the "?" button).
class DuoTutorialPage extends StatefulWidget {
  final VoidCallback onContinue;
  final bool showDontAskAgain;

  const DuoTutorialPage({
    Key? key,
    required this.onContinue,
    this.showDontAskAgain = true,
  }) : super(key: key);

  @override
  State<DuoTutorialPage> createState() => _DuoTutorialPageState();
}

class _DuoTutorialPageState extends State<DuoTutorialPage> {
  bool _dontShowAgain = false;
  final _scrollController = ScrollController();
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Check after first frame whether content overflows
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    final sc = _scrollController;
    if (!sc.hasClients) return;
    final atBottom =
        sc.position.pixels >= sc.position.maxScrollExtent - 4;
    final hasOverflow = sc.position.maxScrollExtent > 0;
    final newValue = hasOverflow && !atBottom;
    if (newValue != _canScrollDown) setState(() => _canScrollDown = newValue);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTutorialSeenKey, true);
    }
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor =
        customTheme?.preferenceButtonColor ?? appTheme.primaryColor;
    final bgColor = appTheme.scaffoldBackgroundColor;

    const steps = [
      _TutorialStep(
        icon: Icons.edit_note_rounded,
        title: 'Answer Independently',
        description:
            'Each player reads the same question and writes their own honest answer — no peeking!',
      ),
      _TutorialStep(
        icon: Icons.visibility_rounded,
        title: 'Reveal Together',
        description:
            'Once both players submit, your answers are revealed at the same time so you can read each other\'s perspective.',
      ),
      _TutorialStep(
        icon: Icons.compare_arrows_rounded,
        title: 'Choose: Match or Differ',
        description:
            'Did you feel a deep connection on this one, or do you see things differently? Pick your verdict.',
      ),
      _TutorialStep(
        icon: Icons.auto_awesome_rounded,
        title: 'See Your Duo Recap',
        description:
            'After all questions, get a beautiful summary showing where you connected and where you diverged.',
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Close / back button ──────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: fontColor.withOpacity(0.4), size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // ── Scrollable content with bottom fade hint ─────────────────
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                    child: Column(
                      children: [
                        // ── Header ────────────────────────────────────────
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.people_rounded,
                              size: 36, color: accentColor),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'How Duo Mode Works',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: fontColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A shared reflection experience for two.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: fontColor.withOpacity(0.5),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Steps ─────────────────────────────────────────
                        ...List.generate(steps.length, (i) {
                          final step = steps[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon column
                                Column(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(step.icon,
                                          size: 20, color: accentColor),
                                    ),
                                    if (i < steps.length - 1)
                                      Container(
                                        width: 2,
                                        height: 16,
                                        margin: const EdgeInsets.only(top: 4),
                                        color: accentColor.withOpacity(0.15),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                // Text
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.title,
                                          style: TextStyle(
                                            fontFamily: 'Runtime',
                                            color: fontColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          step.description,
                                          style: TextStyle(
                                            fontFamily: 'Runtime',
                                            color: fontColor.withOpacity(0.6),
                                            fontSize: 12.5,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 6),

                        // ── Skip tip ─────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: fontColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: fontColor.withOpacity(0.10)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.skip_next_rounded,
                                  size: 16,
                                  color: fontColor.withOpacity(0.45)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Each player has 3 skips per session. Skipping a card skips it for both of you.',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    color: fontColor.withOpacity(0.55),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // ── Scroll-down hint (fades out once at bottom) ──────────
                  AnimatedOpacity(
                    opacity: _canScrollDown ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                bgColor.withOpacity(0),
                                bgColor.withOpacity(0.92),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                              color: fontColor.withOpacity(0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pinned bottom area: checkbox + CTA ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showDontAskAgain) ...[
                    GestureDetector(
                      onTap: () =>
                          setState(() => _dontShowAgain = !_dontShowAgain),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _dontShowAgain,
                              activeColor: accentColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              onChanged: (v) => setState(
                                  () => _dontShowAgain = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Don\'t show again',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: fontColor.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Let's go!",
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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

class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}
