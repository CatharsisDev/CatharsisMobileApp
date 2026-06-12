import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Phases of a single card in the new reflection-first flow.
enum _CardPhase {
  writing,          // Player is typing their answer
  waitingForPartner, // Submitted, waiting for partner to submit
  choosingMatch,    // Both submitted — overlay shows both answers + choice buttons
  waitingForChoice, // I chose, waiting for partner's choice
  showingResult,    // Both chose — overlay shows result briefly then auto-advances
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

  // ── Card-level state ─────────────────────────────────────────────────────
  _CardPhase _phase = _CardPhase.writing;
  String? _myMatchChoice;    // 'matched' | 'differed' once chosen locally
  bool _isSubmitting = false; // true while saveReflection is in flight
  bool _partnerLeftDialogShown = false;

  // Tracks which card we are displaying locally.
  // We manage this ourselves (not session.currentCardIndex) so the reveal
  // fires correctly even if the stream has already advanced.
  int _displayedCardIndex = 0;

  // Text controller for the player's answer
  late TextEditingController _myReflectionController;

  // Auto-advance timer after showingResult
  Timer? _advanceTimer;

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
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _myReflectionController.dispose();
    _advanceTimer?.cancel();
    super.dispose();
  }

  bool get _isHost => ref.read(duoIsHostProvider);

  bool get _isShowingOverlay =>
      _phase == _CardPhase.choosingMatch ||
      _phase == _CardPhase.waitingForChoice ||
      _phase == _CardPhase.showingResult;

  // ── Session update handler ───────────────────────────────────────────────

  void _onSessionUpdate(DuoSession? session) {
    if (session == null) return;

    // Partner left — show dialog once
    if (session.status == DuoSessionStatus.cancelled) {
      if (_partnerLeftDialogShown) return;
      _partnerLeftDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final alertTheme = Theme.of(context);
        final alertCustom = alertTheme.extension<CustomThemeExtension>();
        final alertFontColor =
            alertCustom?.fontColor ?? alertTheme.textTheme.bodyMedium?.color ?? Colors.black87;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: alertTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Partner left',
                style: TextStyle(color: alertFontColor, fontWeight: FontWeight.w700, fontSize: 18)),
            content: Text('Your partner has left the session.',
                style: TextStyle(color: alertFontColor.withOpacity(0.6), fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/home');
                },
                child: Text('Go home',
                    style: TextStyle(color: _duoAccent(alertTheme))),
              ),
            ],
          ),
        );
      });
      return;
    }

    if (_displayedCardIndex >= session.cards.length) return;
    final card = session.cards[_displayedCardIndex];
    final myReflection =
        _isHost ? card.hostReflection : card.guestReflection;
    final partnerReflection =
        _isHost ? card.guestReflection : card.hostReflection;
    final partnerChoice =
        _isHost ? card.guestMatchChoice : card.hostMatchChoice;

    switch (_phase) {
      case _CardPhase.writing:
        // If we reconnected mid-session and I already submitted, restore state
        if (myReflection.isNotEmpty) {
          _myReflectionController.text = myReflection;
          if (partnerReflection.isNotEmpty) {
            setState(() => _phase = _CardPhase.choosingMatch);
            _overlayController.forward(from: 0);
          } else {
            setState(() => _phase = _CardPhase.waitingForPartner);
          }
        }

      case _CardPhase.waitingForPartner:
        if (partnerReflection.isNotEmpty) {
          setState(() => _phase = _CardPhase.choosingMatch);
          _overlayController.forward(from: 0);
        }

      case _CardPhase.choosingMatch:
        // Nothing — waiting for user to tap Matched / Differed
        break;

      case _CardPhase.waitingForChoice:
        if (partnerChoice != null) {
          setState(() => _phase = _CardPhase.showingResult);
          _advanceTimer?.cancel();
          _advanceTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) _dismissReveal(session);
          });
        }

      case _CardPhase.showingResult:
        // Timer handles the advance
        break;
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _submitReflection(DuoSession session) async {
    final text = _myReflectionController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    await DuoSessionService.saveReflection(
      code: widget.sessionCode,
      cardIndex: _displayedCardIndex,
      isHost: _isHost,
      text: text,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _phase = _CardPhase.waitingForPartner;
    });
    // _onSessionUpdate will fire via the stream and transition to choosingMatch
    // if partner already answered.
  }

  Future<void> _recordMatchChoice(DuoSession session, String choice) async {
    if (_myMatchChoice != null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _myMatchChoice = choice;
      _phase = _CardPhase.waitingForChoice;
    });

    await DuoSessionService.recordMatchChoice(
      code: widget.sessionCode,
      cardIndex: _displayedCardIndex,
      isHost: _isHost,
      choice: choice,
    );
    // _onSessionUpdate will transition to showingResult when partner responds.
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
      });
      if (nextIdx >= session.cards.length) {
        _finishSession();
      }
    });
  }

  Future<void> _finishSession() async {
    await DuoSessionService.completeSession(widget.sessionCode);
    if (mounted) context.pushReplacement('/duo/summary/${widget.sessionCode}');
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionAsync =
        ref.watch(duoSessionStreamProvider(widget.sessionCode));
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
        body: Center(child: Text('Error: $e')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            backgroundColor: bgColor,
            body: Center(
              child: Text('Session not found',
                  style: TextStyle(color: fontColor.withOpacity(0.5))),
            ),
          );
        }

        // React to live updates after build
        WidgetsBinding.instance.addPostFrameCallback((_) => _onSessionUpdate(session));

        // Waiting screen while partner hasn't joined
        if (session.isWaiting) {
          return _WaitingForPartnerScreen(sessionCode: widget.sessionCode, hostName: session.hostName);
        }

        final idx = _displayedCardIndex;

        // All done — navigate to summary
        if (session.isComplete || idx >= session.cards.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.pushReplacement('/duo/summary/${widget.sessionCode}');
          });
          return Scaffold(
            backgroundColor: bgColor,
            body: Center(child: CircularProgressIndicator(color: accentColor)),
          );
        }

        final card = session.cards[idx];
        final partnerReflection =
            _isHost ? card.guestReflection : card.hostReflection;
        final partnerName =
            _isHost ? (session.guestName ?? 'Partner') : session.hostName;

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
                      partnerHasAnswered: partnerReflection.isNotEmpty,
                    ),
                    Flexible(
                      child: _buildCard(card, idx, session.cards.length),
                    ),
                    if (!_isShowingOverlay) ...[
                      _buildAnswerArea(session),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),

              // Reveal overlay — fades in when both players have answered
              if (_isShowingOverlay)
                FadeTransition(
                  opacity: _overlayFade,
                  child: _buildRevealOverlay(session, idx, partnerName),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                  'Duo Mode',
                  style: TextStyle(
                    color: fontColor.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Card ${idx + 1} of ${session.cards.length}',
                  style: TextStyle(
                    color: fontColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
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
    final category = card.questionCategory;
    final categoryColor = _categoryColor(category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: appTheme.cardColor,
          borderRadius: BorderRadius.circular(28),
          image: (customTheme?.showBackgroundTexture == true &&
                  customTheme?.backgroundImagePath != null)
              ? DecorationImage(
                  image: AssetImage(customTheme!.backgroundImagePath!),
                  fit: BoxFit.cover,
                  opacity: 0.4,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: categoryColor.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: categoryColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: categoryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                card.questionText,
                textAlign: TextAlign.center,
                style: appTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                  fontSize: 20,
                  color: fontColor,
                ),
              ),
              const Spacer(),
              // Progress dots
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
                      color: i == idx
                          ? categoryColor
                          : i < idx
                              ? categoryColor.withOpacity(0.4)
                              : fontColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom area — text input during writing, waiting banner after submit.
  Widget _buildAnswerArea(DuoSession session) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);

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
                'Waiting for partner…',
                style: TextStyle(
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

    // writing phase — text input + submit button
    final dimColor = fontColor.withOpacity(0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your answer',
            style: TextStyle(
              color: fontColor.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _myReflectionController,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            style: TextStyle(color: fontColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Write what this question brings up for you…',
              hintStyle: TextStyle(color: dimColor, fontSize: 14),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Overlay that shows after both players have answered:
  /// - choosingMatch   → both answers + Matched / Differed buttons
  /// - waitingForChoice → both answers + my choice + waiting spinner
  /// - showingResult    → result icon + label
  Widget _buildRevealOverlay(DuoSession session, int idx, String partnerName) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);
    final card = session.cards[idx];
    final myReflection =
        _isHost ? card.hostReflection : card.guestReflection;
    final partnerReflection =
        _isHost ? card.guestReflection : card.hostReflection;

    Widget overlayContent;

    if (_phase == _CardPhase.showingResult) {
      final resultColor =
          card.isMatch ? const Color(0xFF4CAF50) : const Color(0xFFF59E0B);
      final resultIcon = card.isMatch
          ? Icons.favorite_rounded
          : Icons.compare_arrows_rounded;
      final resultLabel = card.isMatch
          ? 'You connected!'
          : card.bothDiffered
              ? 'You both see it differently!'
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
              color: resultColor,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
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

      overlayContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReflectionDisplay(
            myName: 'You',
            myText: myReflection,
            partnerName: partnerName,
            partnerText: partnerReflection,
            fontColor: fontColor,
            accentColor: accentColor,
          ),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                'Waiting for $partnerName…',
                style: TextStyle(
                    color: fontColor.withOpacity(0.5), fontSize: 13),
              ),
            ],
          ),
        ],
      );
    } else {
      // choosingMatch — show both answers and choice buttons
      overlayContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Both answered!',
            style: TextStyle(
              color: fontColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          _ReflectionDisplay(
            myName: 'You',
            myText: myReflection,
            partnerName: partnerName,
            partnerText: partnerReflection,
            fontColor: fontColor,
            accentColor: accentColor,
          ),
          const SizedBox(height: 20),
          Text(
            'Do you feel you connected?',
            style: TextStyle(
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
            margin:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                color: fontColor, fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('Your progress will be lost.',
            style: TextStyle(
                color: fontColor.withOpacity(0.6), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Stay',
                style: TextStyle(color: fontColor.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DuoSessionService.cancelSession(widget.sessionCode);
              if (mounted) context.go('/home');
            },
            child: const Text('Leave',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Love and Intimacy':
        return const Color(0xFFE57373);
      case 'Spirituality':
        return const Color(0xFF81C784);
      case 'Society':
        return const Color(0xFF64B5F6);
      case 'Interactions and Relationships':
        return const Color(0xFFFFB74D);
      case 'Personal Development':
        return const Color(0xFFCA4ED1);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

// ── Waiting screen (pre-game, partner not joined yet) ────────────────────────

class _WaitingForPartnerScreen extends ConsumerWidget {
  final String sessionCode;
  final String hostName;

  const _WaitingForPartnerScreen({
    required this.sessionCode,
    required this.hostName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);

    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: fontColor, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: accentColor),
                const SizedBox(height: 32),
                Text(
                  'Waiting for partner…',
                  style: TextStyle(
                    color: fontColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Share this code with your partner:',
                  style: TextStyle(color: fontColor.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 20),
                _CodeDisplay(
                  code: sessionCode,
                  accentColor: accentColor,
                  fontColor: fontColor,
                ),
                const SizedBox(height: 32),
                Text(
                  'The session will start automatically once they join.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: fontColor.withOpacity(0.5), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code copied!'),
            duration: Duration(seconds: 2),
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

// ── Helper widgets ───────────────────────────────────────────────────────────

/// Shows partner's current status in the header.
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
    final chipColor =
        hasAnswered ? doneColor : fontColor.withOpacity(0.12);
    final textColor =
        hasAnswered ? doneColor : fontColor.withOpacity(0.45);

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

/// Displays both players' answers side-by-side in the reveal overlay.
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
              color: nameColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text.isEmpty ? '…' : text,
            style: TextStyle(color: fontColor, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Matched / Differed choice button shown in the reveal overlay.
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
