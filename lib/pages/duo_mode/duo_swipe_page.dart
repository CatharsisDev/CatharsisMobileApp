import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/duo_session.dart';
import '../../provider/auth_provider.dart';
import '../../provider/duo_provider.dart';
import '../../provider/theme_provider.dart';
import '../../services/duo_session_service.dart';
import '../../services/subscription_service.dart';

/// Returns the button accent color for duo mode — mirrors existing app buttons.
Color _duoAccent(ThemeData t) {
  return t.extension<CustomThemeExtension>()?.preferenceButtonColor ?? t.primaryColor;
}

/// Phases of a single card in the reflection-first flow.
enum _CardPhase {
  writing,            // Player is typing their answer
  waitingForPartner,  // Submitted, waiting for partner to submit
  choosingMatch,      // Both submitted — overlay shows both answers + choice buttons
  waitingForChoice,   // I chose, waiting for partner's choice
  showingResult,      // Both chose — overlay shows result briefly then auto-advances
}

class DuoSwipePage extends ConsumerStatefulWidget {
  final String sessionCode;
  const DuoSwipePage({Key? key, required this.sessionCode}) : super(key: key);

  @override
  ConsumerState<DuoSwipePage> createState() => _DuoSwipePageState();
}

class _DuoSwipePageState extends ConsumerState<DuoSwipePage>
    with TickerProviderStateMixin {
  // ── Overlay animation ────────────────────────────────────────────────────
  late AnimationController _overlayController;
  late Animation<double> _overlayFade;

  // ── Card timer & pulse ───────────────────────────────────────────────────
  static const int _kCardDuration = 45;
  int _secondsLeft = _kCardDuration;
  Timer? _cardTimer;
  bool _timerStarted = false; // guards against starting timer before session is active

  /// Pulse controller — starts repeating when ≤ 5 seconds remain.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── Card-level state ─────────────────────────────────────────────────────
  _CardPhase _phase = _CardPhase.writing;
  String? _myMatchChoice;
  bool _isSubmitting = false;
  bool _isSkipping = false;
  bool _partnerLeftDialogShown = false;

  int _displayedCardIndex = 0;
  /// Tracks the question text of the card currently being displayed.
  /// When the server replaces a skipped card, this changes and we reset local state.
  String? _trackedQuestionText;
  late TextEditingController _myReflectionController;
  Timer? _advanceTimer;

  // ── Skip toast banner ────────────────────────────────────────────────────
  late AnimationController _skipBannerCtrl;
  late Animation<double> _skipBannerSlide;
  late Animation<double> _skipBannerFade;
  Timer? _skipBannerTimer;
  String _skipBannerText = '';

  @override
  void initState() {
    super.initState();
    _myReflectionController = TextEditingController();

    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _overlayFade = CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeInOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _skipBannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _skipBannerSlide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _skipBannerCtrl, curve: Curves.easeOutCubic),
    );
    _skipBannerFade = CurvedAnimation(
      parent: _skipBannerCtrl, curve: Curves.easeOut,
    );

    // Timer is started from _onSessionUpdate once the session is active,
    // so both players always get a full 45 s regardless of waiting time.
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _myReflectionController.dispose();
    _pulseController.dispose();
    _skipBannerCtrl.dispose();
    _skipBannerTimer?.cancel();
    _advanceTimer?.cancel();
    _cardTimer?.cancel();
    super.dispose();
  }

  bool get _isHost => ref.read(duoIsHostProvider);

  String? get _myUid => ref.read(authStateProvider).value?.uid;

  // ── Group-mode helpers ───────────────────────────────────────────────────

  String _myReflection(DuoSession session, DuoCard card) {
    if (session.isGroupMode) {
      return card.playerReflections[_myUid ?? ''] ?? '';
    }
    return _isHost ? card.hostReflection : card.guestReflection;
  }

  bool _allReflectionsDone(DuoSession session, DuoCard card) {
    if (session.isGroupMode) {
      return card.reflectionsCompleteForGroup(session.participantUids);
    }
    final partnerReflection =
        _isHost ? card.guestReflection : card.hostReflection;
    return partnerReflection.isNotEmpty;
  }

  bool _allVotesDone(DuoSession session, DuoCard card) {
    if (session.isGroupMode) {
      return card.isCompleteForGroup(session.participantUids);
    }
    final partnerChoice =
        _isHost ? card.guestMatchChoice : card.hostMatchChoice;
    return partnerChoice != null;
  }

  /// The display label for the "partner" chip in the header.
  /// For group mode, shows the first other player's name + overflow count.
  String _partnerDisplayLabel(DuoSession session) {
    if (session.isGroupMode) {
      final others = session.participants.entries
          .where((e) => e.key != _myUid)
          .map((e) => e.value)
          .toList();
      if (others.isEmpty) return 'Group';
      if (others.length == 1) return others.first;
      return '${others.first} +${others.length - 1}';
    }
    return _isHost ? (session.guestName ?? 'Partner') : session.hostName;
  }

  /// Whether the current player has already submitted their vote for this card.
  bool _myVoteSubmitted(DuoSession session, DuoCard card) {
    if (session.isGroupMode) {
      return card.playerVotes.containsKey(_myUid ?? '');
    }
    final myChoice = _isHost ? card.hostMatchChoice : card.guestMatchChoice;
    return myChoice != null;
  }

  bool get _isShowingOverlay =>
      _phase == _CardPhase.choosingMatch ||
      _phase == _CardPhase.waitingForChoice ||
      _phase == _CardPhase.showingResult;

  // ── Card timer ───────────────────────────────────────────────────────────

  void _startCardTimer() {
    _cardTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    if (!mounted) return;
    setState(() => _secondsLeft = _kCardDuration);

    _cardTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_phase != _CardPhase.writing) { t.cancel(); return; }

      setState(() {
        _secondsLeft = (_secondsLeft - 1).clamp(0, _kCardDuration);
      });

      // Tension haptics
      if (_secondsLeft == 10) HapticFeedback.lightImpact();
      if (_secondsLeft == 5) {
        HapticFeedback.mediumImpact();
        if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
      }
      if (_secondsLeft == 3 || _secondsLeft == 2 || _secondsLeft == 1) {
        HapticFeedback.lightImpact();
      }

      if (_secondsLeft <= 0) {
        t.cancel();
        // Auto-submit on timeout — reads session from provider
        final session = ref.read(duoSessionStreamProvider(widget.sessionCode)).value;
        if (session != null && mounted) _autoSubmitOnTimeout(session);
      }
    });
  }

  Future<void> _autoSubmitOnTimeout(DuoSession session) async {
    if (_phase != _CardPhase.writing || _isSubmitting) return;
    // Submit whatever they typed; fall back to "…" if nothing
    if (_myReflectionController.text.trim().isEmpty) {
      _myReflectionController.text = '…';
    }
    await _submitReflection(session);
  }

  // ── Session update handler ───────────────────────────────────────────────

  void _onSessionUpdate(DuoSession? session) {
    if (session == null) return;

    // Start the card timer the very first time the session becomes active.
    // Doing it here (not in initState) ensures both players get a full 45 s
    // regardless of how long they waited in the lobby.
    if (!session.isWaiting && !_timerStarted) {
      _timerStarted = true;
      _startCardTimer();
    }

    // If the question text for the current card changed, a skip replacement
    // arrived — reset local state so both players see the fresh question.
    // This must also handle waitingForPartner: if Device B already submitted
    // but Device A skips, the card is replaced in Firestore and Device B
    // would be stuck waiting forever without this check.
    if (!session.isWaiting &&
        _displayedCardIndex < session.cards.length &&
        (_phase == _CardPhase.writing ||
         _phase == _CardPhase.waitingForPartner)) {
      final newText = session.cards[_displayedCardIndex].questionText;
      if (_trackedQuestionText != null && _trackedQuestionText != newText) {
        _cardTimer?.cancel();
        _pulseController.stop();
        _pulseController.reset();
        // Capture skip origin before resetting _isSkipping
        final iWasSkipping = _isSkipping;
        setState(() {
          _isSkipping = false;
          _myMatchChoice = null;
          _myReflectionController.clear();
          _trackedQuestionText = newText;
          _phase = _CardPhase.writing; // force back to writing for both phases
        });
        final partnerName = iWasSkipping
            ? null
            : _partnerDisplayLabel(session);
        _showSkipBanner(iWasSkipping
            ? 'You skipped this card'
            : '${partnerName ?? 'Partner'} skipped this card');
        _startCardTimer();
        return;
      }
      // Initialise tracking on first render of this card.
      if (_trackedQuestionText == null) {
        _trackedQuestionText = newText;
      }
    }

    if (session.status == DuoSessionStatus.cancelled) {
      if (_partnerLeftDialogShown) return;
      _partnerLeftDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final alertTheme = Theme.of(context);
        final alertCustom = alertTheme.extension<CustomThemeExtension>();
        final alertFontColor =
            alertCustom?.fontColor ?? alertTheme.textTheme.bodyMedium?.color ?? Colors.black87;
        final accent = _duoAccent(alertTheme);
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              decoration: BoxDecoration(
                color: alertTheme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withOpacity(0.15), width: 1.5),
              ),
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.link_off_rounded, color: accent, size: 26),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Session ended',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: alertFontColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The host left and the session\nwas cancelled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: alertFontColor.withOpacity(0.55),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Go home',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      });
      return;
    }

    if (_displayedCardIndex >= session.cards.length) return;
    final card = session.cards[_displayedCardIndex];
    final myReflection = _myReflection(session, card);

    switch (_phase) {
      case _CardPhase.writing:
        if (myReflection.isNotEmpty) {
          _myReflectionController.text = myReflection;
          if (_allReflectionsDone(session, card)) {
            setState(() => _phase = _CardPhase.choosingMatch);
            _overlayController.forward(from: 0);
          } else {
            setState(() => _phase = _CardPhase.waitingForPartner);
          }
        }

      case _CardPhase.waitingForPartner:
        if (_allReflectionsDone(session, card)) {
          setState(() => _phase = _CardPhase.choosingMatch);
          _overlayController.forward(from: 0);
        }

      case _CardPhase.choosingMatch:
        // If we're in group mode and this player already voted (e.g. hot-reload),
        // jump to waitingForChoice.
        if (session.isGroupMode && _myVoteSubmitted(session, card)) {
          if (_allVotesDone(session, card)) {
            setState(() => _phase = _CardPhase.showingResult);
            _advanceTimer?.cancel();
            _advanceTimer = Timer(const Duration(seconds: 2), () {
              if (mounted) _dismissReveal(session);
            });
          } else {
            setState(() => _phase = _CardPhase.waitingForChoice);
          }
        }

      case _CardPhase.waitingForChoice:
        if (_allVotesDone(session, card)) {
          setState(() => _phase = _CardPhase.showingResult);
          _advanceTimer?.cancel();
          _advanceTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) _dismissReveal(session);
          });
        }

      case _CardPhase.showingResult:
        break;
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _submitReflection(DuoSession session) async {
    final text = _myReflectionController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    // Stop the card timer
    _cardTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    if (session.isGroupMode) {
      final uid = _myUid;
      if (uid != null) {
        await DuoSessionService.savePlayerReflection(
          code: widget.sessionCode,
          cardIndex: _displayedCardIndex,
          uid: uid,
          text: text,
        );
      }
    } else {
      await DuoSessionService.saveReflection(
        code: widget.sessionCode,
        cardIndex: _displayedCardIndex,
        isHost: _isHost,
        text: text,
      );
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _phase = _CardPhase.waitingForPartner;
    });
  }

  Future<void> _recordMatchChoice(DuoSession session, String choice) async {
    if (_myMatchChoice != null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _myMatchChoice = choice;
      _phase = _CardPhase.waitingForChoice;
    });

    if (session.isGroupMode) {
      final uid = _myUid;
      if (uid != null) {
        await DuoSessionService.recordPlayerVote(
          code: widget.sessionCode,
          cardIndex: _displayedCardIndex,
          uid: uid,
          choice: choice,
        );
      }
    } else {
      await DuoSessionService.recordMatchChoice(
        code: widget.sessionCode,
        cardIndex: _displayedCardIndex,
        isHost: _isHost,
        choice: choice,
      );
    }
  }

  Future<void> _skipCurrentCard(DuoSession session) async {
    if (_isSkipping || _isSubmitting) return;
    // Each group player has their own skip budget; 2-player uses host/guest fields.
    final mySkipsLeft = session.isGroupMode
        ? (session.playerSkipsLeft[_myUid ?? ''] ?? 0)
        : (_isHost ? session.hostSkipsLeft : session.guestSkipsLeft);
    if (mySkipsLeft <= 0) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSkipping = true);
    _cardTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    try {
      await DuoSessionService.skipCard(
        code: widget.sessionCode,
        cardIndex: _displayedCardIndex,
        isHost: _isHost,
        // Pass uid for group mode so the correct player's budget is decremented.
        uid: session.isGroupMode ? _myUid : null,
      );
      // Replacement is detected in _onSessionUpdate via question text change.
    } catch (_) {
      // If the skip fails, reset state so the button isn't stuck disabled.
      if (mounted) {
        setState(() => _isSkipping = false);
        _startCardTimer();
      }
    }
  }

  void _showSkipBanner(String text) {
    _skipBannerTimer?.cancel();
    setState(() => _skipBannerText = text);
    _skipBannerCtrl.forward(from: 0);
    _skipBannerTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      _skipBannerCtrl.reverse();
    });
  }

  void _dismissReveal(DuoSession session) {
    _advanceTimer?.cancel();
    _overlayController.reverse().then((_) {
      if (!mounted) return;
      final nextIdx = _displayedCardIndex + 1;
      setState(() {
        _phase = _CardPhase.writing;
        _myMatchChoice = null;
        _myReflectionController.clear();
        _displayedCardIndex = nextIdx;
        _trackedQuestionText = null; // reset so next card initialises cleanly
      });
      if (nextIdx >= session.cards.length) {
        _finishSession();
      } else {
        _startCardTimer(); // restart for the new card
      }
    });
  }

  Future<void> _finishSession() async {
    // Set 3-hour cooldown for non-premium users
    final isPremium = ref.read(isPremiumProvider).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    if (!isPremium) {
      final prefs = await SharedPreferences.getInstance();
      final cooldownUntil = DateTime.now().add(const Duration(hours: 24));
      await prefs.setInt(
          'duo_cooldown_until_ms', cooldownUntil.millisecondsSinceEpoch);
    }

    await DuoSessionService.completeSession(widget.sessionCode);
    // Go to the Wrapped recap slides first, then they navigate to the full summary.
    if (mounted) context.pushReplacement('/duo/wrap/${widget.sessionCode}');
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(duoSessionStreamProvider(widget.sessionCode));
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final bgColor = appTheme.scaffoldBackgroundColor;
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);

    return sessionAsync.when(
      loading: () => Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: bgColor,
        body: Center(child: Text('Error: $e',
            style: const TextStyle(fontFamily: 'Runtime'))),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            backgroundColor: bgColor,
            body: Center(
              child: Text('Session not found',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor.withOpacity(0.5),
                  )),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _onSessionUpdate(session));

        if (session.isWaiting) {
          return _WaitingForPartnerScreen(
            sessionCode: widget.sessionCode,
            session: session,
            isHost: _isHost,
          );
        }

        final idx = _displayedCardIndex;

        if (session.isComplete || idx >= session.cards.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.pushReplacement('/duo/wrap/${widget.sessionCode}');
          });
          return Scaffold(
            backgroundColor: bgColor,
            body: Center(child: CircularProgressIndicator(color: accentColor)),
          );
        }

        final card = session.cards[idx];
        // For group mode: check if any other player has answered
        final partnerHasAnswered = session.isGroupMode
            ? session.participants.keys
                .where((uid) => uid != _myUid)
                .any((uid) => (card.playerReflections[uid] ?? '').isNotEmpty)
            : (_isHost
                ? card.guestReflection.isNotEmpty
                : card.hostReflection.isNotEmpty);
        final partnerName = _partnerDisplayLabel(session);

        return Scaffold(
          backgroundColor: bgColor,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(
                      session: session,
                      idx: idx,
                      partnerName: partnerName,
                      partnerHasAnswered: partnerHasAnswered,
                    ),
                    Flexible(
                      child: _buildCard(card, idx, session.cards.length),
                    ),
                    if (!_isShowingOverlay) ...[
                      _buildAnswerArea(session),
                      SizedBox(
                        height: MediaQuery.of(context).size.height < 700 ? 16 : 24,
                      ),
                    ],
                  ],
                ),
              ),
              if (_isShowingOverlay)
                FadeTransition(
                  opacity: _overlayFade,
                  child: _buildRevealOverlay(session, idx, partnerName),
                ),

              // ── Skip toast banner ────────────────────────────────────────
              AnimatedBuilder(
                animation: _skipBannerCtrl,
                builder: (_, __) {
                  if (_skipBannerCtrl.isDismissed) return const SizedBox.shrink();
                  final accentColor = _duoAccent(Theme.of(context));
                  return Positioned(
                    left: 20,
                    right: 20,
                    top: MediaQuery.of(context).padding.top + 64,
                    child: FractionalTranslation(
                      translation: Offset(0, _skipBannerSlide.value),
                      child: Opacity(
                        opacity: _skipBannerFade.value.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: accentColor.withOpacity(0.30), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.skip_next_rounded,
                                  size: 16, color: accentColor),
                              const SizedBox(width: 8),
                              Text(
                                _skipBannerText,
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Sub-builders ─────────────────────────────────────────────────────────

  Widget _buildHeader({
    required DuoSession session,
    required int idx,
    required String partnerName,
    required bool partnerHasAnswered,
  }) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final iconColor = customTheme?.iconColor ?? fontColor;
    final isSmall = MediaQuery.of(context).size.height < 700;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, isSmall ? 10 : 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: iconColor.withOpacity(0.6), size: 24),
            onPressed: () => _showLeaveDialog(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Circle',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Card ${idx + 1} of ${session.cards.length}',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Countdown ring — visible only during writing phase
          _TimerRing(
            secondsLeft: _secondsLeft,
            totalSeconds: _kCardDuration,
            isActive: _phase == _CardPhase.writing,
          ),
          const SizedBox(width: 10),
          _PartnerChip(
            name: partnerName,
            hasAnswered: partnerHasAnswered,
            accentColor: _duoAccent(appTheme),
            fontColor: fontColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(DuoCard card, int idx, int total) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final bgImagePath = customTheme?.backgroundImagePath;

    // Compute tension state
    final isUrgent  = _phase == _CardPhase.writing && _secondsLeft <= 8;
    final isWarning = _phase == _CardPhase.writing && _secondsLeft > 8 && _secondsLeft <= 15;

    final borderColor = isUrgent
        ? const Color(0xFFEF4444)
        : isWarning
            ? const Color(0xFFF59E0B)
            : fontColor.withOpacity(0.1);
    final borderWidth = isUrgent ? 2.0 : isWarning ? 1.5 : 1.0;

    // Wrap in AnimatedBuilder so the pulse shadow animates at < 5 seconds
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final glowOpacity = (isUrgent && _secondsLeft <= 5)
            ? 0.12 + (_pulseAnim.value * 0.25)
            : 0.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmall ? 6 : 10),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: appTheme.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                if (glowOpacity > 0)
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(glowOpacity),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
              ],
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Stack(
                children: [
                  if (bgImagePath != null)
                    Positioned.fill(
                      child: Image.asset(bgImagePath, fit: BoxFit.cover),
                    ),
                  if (bgImagePath != null)
                    Positioned.fill(
                      child: Container(color: appTheme.cardColor.withOpacity(0.45)),
                    ),
                  Padding(
                    padding: EdgeInsets.all(isSmall ? 18 : 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Question text
                        Expanded(
                          child: Center(
                            child: AutoSizeText(
                              card.questionText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontWeight: FontWeight.bold,
                                fontSize: isSmall
                                    ? size.width * 0.072
                                    : size.width * 0.075,
                                height: 1.35,
                                letterSpacing: 1.2,
                                color: fontColor,
                              ),
                              minFontSize: 15,
                              maxLines: 8,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),

                        SizedBox(height: isSmall ? 12 : 16),

                        // Category chip — neutral
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: fontColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: fontColor.withOpacity(0.18), width: 1),
                          ),
                          child: Text(
                            card.questionCategory,
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: fontColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        SizedBox(height: isSmall ? 12 : 16),

                        // Progress dots — pure neutral (black/white based on brightness)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            total.clamp(0, 10),
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == idx ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: (() {
                                  final base = appTheme.brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black;
                                  return i == idx
                                      ? base.withOpacity(0.65)
                                      : i < idx
                                          ? base.withOpacity(0.30)
                                          : base.withOpacity(0.13);
                                })(),
                                borderRadius: BorderRadius.circular(4),
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
          ),
        );
      },
    );
  }

  /// Bottom area — text input during writing, waiting banner after submit.
  Widget _buildAnswerArea(DuoSession session) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);
    final isSmall = MediaQuery.of(context).size.height < 700;

    if (_phase == _CardPhase.waitingForPartner) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
              ),
              const SizedBox(width: 12),
              Text(
                session.isGroupMode
                    ? 'Waiting for others…'
                    : 'Waiting for partner…',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dimColor = fontColor.withOpacity(0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your answer',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _myReflectionController,
            maxLines: isSmall ? 2 : 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Write what this question brings up for you…',
              hintStyle: TextStyle(
                fontFamily: 'Runtime',
                color: dimColor,
                fontSize: 14,
              ),
              filled: true,
              fillColor: appTheme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: dimColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: dimColor),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submitReflection(session),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                disabledBackgroundColor: accentColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Submit Answer',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),

          // Skip button — shown when the player has skips left AND reserves remain.
          // Group mode: each player has their own budget tracked in playerSkipsLeft.
          Builder(builder: (_) {
            final mySkipsLeft = session.isGroupMode
                ? (session.playerSkipsLeft[_myUid ?? ''] ?? 0)
                : (_isHost ? session.hostSkipsLeft : session.guestSkipsLeft);
            if (mySkipsLeft <= 0 || session.reserveCards.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed:
                      (_isSkipping || _isSubmitting)
                          ? null
                          : () => _skipCurrentCard(session),
                  icon: Icon(
                    Icons.skip_next_rounded,
                    size: 16,
                    color: fontColor.withOpacity(0.4),
                  ),
                  label: Text(
                    'Skip ($mySkipsLeft left)',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: fontColor.withOpacity(0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRevealOverlay(DuoSession session, int idx, String partnerName) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);
    final card = session.cards[idx];
    final myReflection = _myReflection(session, card);

    // For group mode: collect all players' reflections in order
    // (my answer first, then others in participant order)
    List<({String name, String text})> allReflections() {
      if (!session.isGroupMode) {
        final partnerReflection =
            _isHost ? card.guestReflection : card.hostReflection;
        return [
          (name: 'You', text: myReflection),
          (name: partnerName, text: partnerReflection),
        ];
      }
      final result = <({String name, String text})>[];
      final myUid = _myUid ?? '';
      // My reflection first
      result.add((
        name: 'You',
        text: card.playerReflections[myUid] ?? '',
      ));
      // Then everyone else in participant order
      for (final entry in session.participants.entries) {
        if (entry.key == myUid) continue;
        result.add((
          name: entry.value,
          text: card.playerReflections[entry.key] ?? '',
        ));
      }
      return result;
    }

    // Group-aware result check
    bool cardIsMatch() {
      if (session.isGroupMode) {
        return card.isMatchForGroup(session.participantUids);
      }
      return card.isMatch;
    }

    bool cardAllDiffered() {
      if (session.isGroupMode) {
        return card.allDifferedForGroup(session.participantUids);
      }
      return card.bothDiffered;
    }

    Widget overlayContent;

    if (_phase == _CardPhase.showingResult) {
      // Match → green heart.  Differed → red arrows.  Mixed → amber.
      final bool isMatch = cardIsMatch();
      final bool allDiffered = cardAllDiffered();
      final Color resultColor;
      if (isMatch) {
        resultColor = const Color(0xFF4CAF50);
      } else if (allDiffered) {
        resultColor = const Color(0xFFEF4444);
      } else {
        resultColor = const Color(0xFFF59E0B);
      }
      final resultIcon =
          isMatch ? Icons.favorite_rounded : Icons.compare_arrows_rounded;
      final resultLabel = isMatch
          ? (session.isGroupMode ? 'Everyone connected!' : 'You connected!')
          : allDiffered
              ? (session.isGroupMode
                  ? 'You all see it differently!'
                  : 'You both see it differently!')
              : 'Mixed feelings!';

      overlayContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: resultColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(resultIcon, color: resultColor, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            resultLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          // In group mode, show a summary of who voted what
          if (session.isGroupMode) ...[
            const SizedBox(height: 12),
            ...session.participants.entries.map((e) {
              final vote = card.playerVotes[e.key];
              final isVoteMatch = vote == 'matched';
              final voteColor = isVoteMatch
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFF59E0B);
              final name = e.key == (_myUid ?? '') ? 'You' : e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVoteMatch
                          ? Icons.favorite_rounded
                          : Icons.compare_arrows_rounded,
                      size: 14,
                      color: voteColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$name: ${vote ?? '—'}',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: fontColor.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      );
    } else if (_phase == _CardPhase.waitingForChoice) {
      final choiceColor = _myMatchChoice == 'matched'
          ? const Color(0xFF4CAF50)
          : const Color(0xFFF59E0B);
      final choiceIcon = _myMatchChoice == 'matched'
          ? Icons.favorite_rounded
          : Icons.compare_arrows_rounded;
      final choiceLabel =
          _myMatchChoice == 'matched' ? 'You chose: Matched' : 'You chose: Differed';

      final reflections = allReflections();

      overlayContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.isGroupMode)
            _GroupReflectionDisplay(
              reflections: reflections,
              fontColor: fontColor,
              accentColor: accentColor,
            )
          else
            _ReflectionDisplay(
              myName: 'You',
              myText: myReflection,
              partnerName: partnerName,
              partnerText: reflections.length > 1 ? reflections[1].text : '',
              fontColor: fontColor,
              accentColor: accentColor,
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: choiceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: choiceColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(choiceIcon, size: 16, color: choiceColor),
                const SizedBox(width: 8),
                Text(
                  choiceLabel,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: choiceColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                session.isGroupMode
                    ? 'Waiting for others…'
                    : 'Waiting for $partnerName…',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: fontColor.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // choosingMatch — show all answers and choice buttons
      final reflections = allReflections();
      overlayContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            session.isGroupMode ? 'Everyone answered!' : 'Both answered!',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          if (session.isGroupMode)
            _GroupReflectionDisplay(
              reflections: reflections,
              fontColor: fontColor,
              accentColor: accentColor,
            )
          else
            _ReflectionDisplay(
              myName: 'You',
              myText: myReflection,
              partnerName: partnerName,
              partnerText: reflections.length > 1 ? reflections[1].text : '',
              fontColor: fontColor,
              accentColor: accentColor,
            ),
          const SizedBox(height: 20),
          Text(
            'Do you feel you connected?',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Differed',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _recordMatchChoice(session, 'differed'),
                  cardColor: appTheme.cardColor,
                  fontColor: fontColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceButton(
                  icon: Icons.favorite_rounded,
                  label: 'Matched',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _recordMatchChoice(session, 'matched'),
                  cardColor: appTheme.cardColor,
                  fontColor: fontColor,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: MediaQuery.of(context).size.height < 700 ? 24 : 40,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: appTheme.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _duoAccent(appTheme).withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: overlayContent,
          ),
        ),
      ),
    );
  }

  void _showLeaveDialog() {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: appTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Leave Session?',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            )),
        content: Text('Your progress will be lost.',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor.withOpacity(0.6),
              fontSize: 14,
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Stay',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: fontColor.withOpacity(0.5),
                )),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DuoSessionService.cancelSession(widget.sessionCode);
              if (mounted) context.go('/home');
            },
            child: const Text('Leave',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: Color(0xFFEF4444),
                )),
          ),
        ],
      ),
    );
  }
}

// ── Timer ring widget ─────────────────────────────────────────────────────────

class _TimerRing extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final bool isActive;

  const _TimerRing({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox(width: 38, height: 38);

    final progress = (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final Color ringColor;
    if (secondsLeft <= 8) {
      ringColor = const Color(0xFFEF4444); // red
    } else if (secondsLeft <= 15) {
      ringColor = const Color(0xFFF59E0B); // amber
    } else {
      ringColor = const Color(0xFF4CAF50); // green
    }

    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3.5,
            backgroundColor: ringColor.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(ringColor),
          ),
          Text(
            '$secondsLeft',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: ringColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waiting screen ────────────────────────────────────────────────────────────

class _WaitingForPartnerScreen extends ConsumerStatefulWidget {
  final String sessionCode;
  final DuoSession session;
  final bool isHost;

  const _WaitingForPartnerScreen({
    required this.sessionCode,
    required this.session,
    required this.isHost,
  });

  @override
  ConsumerState<_WaitingForPartnerScreen> createState() =>
      _WaitingForPartnerScreenState();
}

class _WaitingForPartnerScreenState
    extends ConsumerState<_WaitingForPartnerScreen> {
  bool _isStarting = false;
  bool _isLeaving = false;

  Future<void> _startGame() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      await DuoSessionService.startSession(widget.sessionCode);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  /// Called when the user presses the back button in the waiting room.
  /// Host: shows a confirmation dialog, then cancels the session for everyone.
  /// Non-host: silently removes themselves from [participants] and goes home.
  Future<void> _onLeave() async {
    if (_isLeaving) return;
    if (widget.isHost) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final t = Theme.of(ctx);
          final c = t.extension<CustomThemeExtension>();
          final fc = c?.fontColor ?? t.textTheme.bodyMedium?.color ?? Colors.black87;
          return AlertDialog(
            backgroundColor: t.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Cancel session?',
                style: TextStyle(
                    fontFamily: 'Runtime', color: fc, fontWeight: FontWeight.w700)),
            content: Text(
              'Leaving will cancel the session for everyone in the lobby.',
              style: TextStyle(
                  fontFamily: 'Runtime', color: fc.withOpacity(0.65), fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Stay',
                    style: TextStyle(
                        fontFamily: 'Runtime', color: _duoAccent(t))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Cancel session',
                    style: TextStyle(
                        fontFamily: 'Runtime',
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
      if (confirm != true) return;
    }

    setState(() => _isLeaving = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      await DuoSessionService.leaveSession(
        code: widget.sessionCode,
        uid: uid,
        isHost: widget.isHost,
      );
    } catch (_) {
      // Best-effort — navigate away regardless.
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);
    final isSmall = MediaQuery.of(context).size.height < 700;
    final session = widget.session;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onLeave();
      },
      child: Scaffold(
        backgroundColor: appTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: appTheme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: fontColor, size: 20),
            onPressed: _onLeave,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: session.isGroupMode
                  ? _buildGroupWaiting(
                      context, session, fontColor, accentColor, isSmall)
                  : _buildDuoWaiting(
                      context, session, fontColor, accentColor, isSmall),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuoWaiting(
    BuildContext context,
    DuoSession session,
    Color fontColor,
    Color accentColor,
    bool isSmall,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: accentColor),
        SizedBox(height: isSmall ? 20 : 32),
        Text(
          'Waiting for partner…',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor,
            fontWeight: FontWeight.w700,
            fontSize: isSmall ? 20 : 22,
          ),
        ),
        SizedBox(height: isSmall ? 8 : 12),
        Text(
          'Share this code with your partner:',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        SizedBox(height: isSmall ? 14 : 20),
        _CodeDisplay(
          code: session.sessionCode,
          accentColor: accentColor,
          fontColor: fontColor,
        ),
        SizedBox(height: isSmall ? 20 : 32),
        Text(
          'The session will start automatically once they join.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupWaiting(
    BuildContext context,
    DuoSession session,
    Color fontColor,
    Color accentColor,
    bool isSmall,
  ) {
    final joined = session.joinedCount;
    final max = session.maxPlayers;
    final canStart = joined >= 2 && widget.isHost;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          Text(
            'Group Session',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor,
              fontWeight: FontWeight.w800,
              fontSize: isSmall ? 20 : 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$joined of $max players joined',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: accentColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          SizedBox(height: isSmall ? 16 : 24),

          // Session code
          Text(
            'Share this code:',
            style: TextStyle(
              fontFamily: 'Runtime',
              color: fontColor.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _CodeDisplay(
            code: session.sessionCode,
            accentColor: accentColor,
            fontColor: fontColor,
          ),

          SizedBox(height: isSmall ? 16 : 24),

          // Player list
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                // Connected players
                ...session.participants.values.map((name) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: fontColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )),
                // Empty slots
                ...List.generate(max - joined, (_) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: fontColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Waiting for player…',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: fontColor.withOpacity(0.35),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          SizedBox(height: isSmall ? 16 : 24),

          // Start button (host) or waiting text (others)
          if (widget.isHost) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canStart ? _startGame : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  disabledBackgroundColor: accentColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isStarting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        joined >= max
                            ? 'Start Game'
                            : 'Start Now ($joined/$max joined)',
                        style: const TextStyle(
                          fontFamily: 'Runtime',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            if (!canStart) ...[
              const SizedBox(height: 8),
              Text(
                'Need at least 2 players to start.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: fontColor.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  'Waiting for host to start…',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeDisplay extends StatelessWidget {
  final String code;
  final Color accentColor;
  final Color fontColor;
  const _CodeDisplay({
    required this.code,
    required this.accentColor,
    required this.fontColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            backgroundColor: Colors.transparent,
            elevation: 0,
            duration: const Duration(seconds: 2),
            content: Container(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Code copied!',
                    style: const TextStyle(
                      fontFamily: 'Runtime',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: TextStyle(
                fontFamily: 'Runtime',
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: accentColor,
                fontSize: 28,
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.copy_rounded, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _PartnerChip extends StatelessWidget {
  final String name;
  final bool hasAnswered;
  final Color accentColor;
  final Color fontColor;

  const _PartnerChip({
    required this.name,
    required this.hasAnswered,
    required this.accentColor,
    required this.fontColor,
  });

  @override
  Widget build(BuildContext context) {
    const doneColor = Color(0xFF4CAF50);
    final chipColor = hasAnswered ? doneColor : fontColor.withOpacity(0.12);
    final textColor = hasAnswered ? doneColor : fontColor.withOpacity(0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasAnswered ? doneColor.withOpacity(0.12) : chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasAnswered ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Runtime',
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionDisplay extends StatelessWidget {
  final String myName;
  final String myText;
  final String partnerName;
  final String partnerText;
  final Color fontColor;
  final Color accentColor;

  const _ReflectionDisplay({
    required this.myName,
    required this.myText,
    required this.partnerName,
    required this.partnerText,
    required this.fontColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bubble(
          name: myName,
          text: myText,
          nameColor: accentColor,
          bgColor: accentColor.withOpacity(0.08),
          borderColor: accentColor.withOpacity(0.2),
        ),
        const SizedBox(height: 8),
        _bubble(
          name: partnerName,
          text: partnerText,
          nameColor: fontColor.withOpacity(0.55),
          bgColor: fontColor.withOpacity(0.06),
          borderColor: fontColor.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget _bubble({
    required String name,
    required String text,
    required Color nameColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Runtime',
              color: nameColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text.isEmpty ? '…' : text,
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

/// Like [_ReflectionDisplay] but for 3-4 player group mode.
/// Shows each player's reflection as a stacked bubble.
class _GroupReflectionDisplay extends StatelessWidget {
  final List<({String name, String text})> reflections;
  final Color fontColor;
  final Color accentColor;

  const _GroupReflectionDisplay({
    required this.reflections,
    required this.fontColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: reflections.asMap().entries.map((e) {
        final idx = e.key;
        final r = e.value;
        final isMe = idx == 0;
        final nameColor = isMe ? accentColor : fontColor.withOpacity(0.55);
        final bgColor = isMe ? accentColor.withOpacity(0.08) : fontColor.withOpacity(0.06);
        final borderColor = isMe ? accentColor.withOpacity(0.2) : fontColor.withOpacity(0.1);
        return Padding(
          padding: EdgeInsets.only(bottom: idx < reflections.length - 1 ? 8 : 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: nameColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  r.text.isEmpty ? '…' : r.text,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Color cardColor;
  final Color fontColor;

  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.cardColor,
    required this.fontColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.45), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Runtime',
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
