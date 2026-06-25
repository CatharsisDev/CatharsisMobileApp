import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../provider/theme_provider.dart';
import '../../provider/auth_provider.dart';
import '../../provider/duo_provider.dart';
import '../../provider/user_profile_provider.dart';
import '../../services/duo_session_service.dart';
import '../../services/subscription_service.dart';
import '../subscription_plans/subscription_plans_page.dart';
import 'duo_past_sessions_page.dart';
import 'duo_tutorial_page.dart';
import '../../components/circle_mode_icon.dart';

class DuoLobbyPage extends ConsumerStatefulWidget {
  const DuoLobbyPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DuoLobbyPage> createState() => _DuoLobbyPageState();
}

/// Returns the button accent color for duo mode — mirrors existing app buttons.
Color _duoAccent(ThemeData t) {
  return t.extension<CustomThemeExtension>()?.preferenceButtonColor ?? t.primaryColor;
}

class _DuoLobbyPageState extends ConsumerState<DuoLobbyPage> {
  late final TextEditingController _codeController = TextEditingController()
    ..addListener(() {
      if (_joinError != null) setState(() => _joinError = null);
    });

  bool _isCreating = false;
  bool _isJoining = false;
  String? _errorMessage;   // general errors (create session)
  String? _joinError;      // join-specific error shown inline in the card
  int _questionCount = 10;
  int _maxPlayers = 2;     // 2 = classic duo, 3-4 = group mode

  /// Null means "all categories". Non-null is the set the user has chosen.
  Set<String>? _selectedCategories;

  // Cooldown state
  DateTime? _cooldownUntil;
  Timer? _cooldownRefreshTimer;

  bool get _cooldownActive =>
      _cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadCooldown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownRefreshTimer?.cancel();
    super.dispose();
  }

  // ── Cooldown ─────────────────────────────────────────────────────────────

  Future<void> _loadCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('duo_cooldown_until_ms');
    if (ms != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      if (dt.isAfter(DateTime.now())) {
        if (mounted) setState(() => _cooldownUntil = dt);
        _startCooldownRefreshTimer();
      } else {
        // Expired — clean up
        await prefs.remove('duo_cooldown_until_ms');
      }
    }
  }

  /// Debug-only: wipes the cooldown from SharedPreferences so you can create
  /// another session immediately. Only shown in the UI when a cooldown is active.
  Future<void> _resetCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('duo_cooldown_until_ms');
    if (mounted) setState(() => _cooldownUntil = null);
    _cooldownRefreshTimer?.cancel();
  }

  void _startCooldownRefreshTimer() {
    _cooldownRefreshTimer?.cancel();
    // Refresh every 30 seconds so the displayed time stays reasonably accurate
    _cooldownRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (!_cooldownActive) {
        _cooldownRefreshTimer?.cancel();
      }
      setState(() {});
    });
  }

  // ── Session actions ───────────────────────────────────────────────────────

  /// Shows the tutorial if it hasn't been seen, then runs [onProceed].
  Future<void> _maybeShowTutorial(VoidCallback onProceed) async {
    final seen = await isDuoTutorialSeen();
    if (!mounted) return;
    if (seen) {
      onProceed();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuoTutorialPage(
          showDontAskAgain: true,
          onContinue: () {
            Navigator.of(context).pop();
            onProceed();
          },
        ),
      ),
    );
  }

  Future<void> _createSession(bool isPremium) async {
    // Guard: non-premium users must wait out their cooldown
    if (!isPremium && _cooldownActive) return;

    // Show tutorial on first run, then proceed
    await _maybeShowTutorial(() => _doCreateSession(isPremium));
  }

  Future<void> _doCreateSession(bool isPremium) async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not logged in');

      // Use Duo-specific compatibility questions
      var questions = ref.read(duoQuestionsProvider).valueOrNull ?? [];

      if (questions.isEmpty) {
        throw Exception('No questions available. Please try again.');
      }

      // Apply category filter if the user chose specific categories
      if (_selectedCategories != null && _selectedCategories!.isNotEmpty) {
        questions = questions
            .where((q) => _selectedCategories!.contains(q.category))
            .toList();
      }

      if (questions.isEmpty) throw Exception('No cards available for the selected categories. Try selecting more categories.');

      final username = ref.read(userUsernameProvider);
      final displayName = username?.isNotEmpty == true
          ? username!
          : (user.displayName?.isNotEmpty == true
              ? user.displayName!
              : user.email?.split('@').first ?? 'Host');

      // Shuffle so same categories don't always appear first
      final shuffled = List.of(questions)..shuffle();

      // First _questionCount questions are the main deck;
      // up to 6 extras become the reserve pool for skip replacements.
      final mainQuestions = shuffled.take(_questionCount).toList();
      final reserveQuestions = shuffled
          .skip(_questionCount)
          .take(6)
          .toList();

      final code = await DuoSessionService.createSession(
        hostUid: user.uid,
        hostName: displayName,
        questions: mainQuestions,
        reserves: reserveQuestions,
        maxPlayers: _maxPlayers,
      );

      ref.read(duoSessionCodeProvider.notifier).state = code;
      ref.read(duoIsHostProvider.notifier).state = true;

      if (mounted) context.push('/duo/session/$code');
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinSession(bool isPremium) async {
    // Joining is always allowed regardless of premium status or cooldown.

    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _joinError = 'Please enter the full 6-character code.');
      return;
    }

    setState(() {
      _isJoining = true;
      _joinError = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not logged in');

      final username = ref.read(userUsernameProvider);
      final displayName = username?.isNotEmpty == true
          ? username!
          : (user.displayName?.isNotEmpty == true
              ? user.displayName!
              : user.email?.split('@').first ?? 'Guest');

      await DuoSessionService.joinSession(
        code: code,
        guestUid: user.uid,
        guestName: displayName,
      );

      ref.read(duoSessionCodeProvider.notifier).state = code;
      ref.read(duoIsHostProvider.notifier).state = false;

      if (mounted) context.push('/duo/session/$code');
    } on FirebaseException catch (e) {
      setState(() => _joinError =
          e.code == 'unavailable' || e.code == 'network-request-failed'
              ? 'No internet connection. Check your network and try again.'
              : 'Something went wrong. Please try again.');
    } catch (e) {
      final raw = e.toString().replaceFirst('Exception: ', '');
      setState(() => _joinError = _friendlyJoinError(raw));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  static String _friendlyJoinError(String raw) {
    if (raw.contains('not found') || raw.contains('No document')) {
      return 'That code doesn\'t exist. Double-check with your partner.';
    }
    if (raw.contains('already started') || raw.contains('ended')) {
      return 'This session has already started or ended.';
    }
    if (raw.contains('own session')) {
      return 'You can\'t join your own session.';
    }
    if (raw.contains('Not logged in')) {
      return 'You need to be logged in to join a session.';
    }
    return raw.isNotEmpty ? raw : 'Something went wrong. Please try again.';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor = customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);
    const errorColor = Color(0xFFEF4444);

    // Premium status — defaults to non-premium while loading / on error (safe)
    final isPremium = ref.watch(isPremiumProvider).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    // Duo questions async state
    final questionsAsync = ref.watch(duoQuestionsProvider);
    final questionsReady = questionsAsync.valueOrNull?.isNotEmpty == true;

    // Clamp question count to the current tier's max
    final maxQuestions = isPremium ? 50 : 20;
    if (_questionCount > maxQuestions) {
      Future.microtask(() {
        if (mounted) setState(() => _questionCount = maxQuestions);
      });
    }

    // Shared AppBar for loading / error states
    AppBar _simpleAppBar() => AppBar(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: fontColor, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Circle',
        style: TextStyle(
          fontFamily: 'Runtime',
          color: fontColor,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
    );

    // ── Full-screen loading state ─────────────────────────────────────────────
    if (questionsAsync is AsyncLoading) {
      return Scaffold(
        backgroundColor: appTheme.scaffoldBackgroundColor,
        appBar: _simpleAppBar(),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Preparing your questions…',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Curating compatibility questions\njust for you.',
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
        ),
      );
    }

    // ── Error / empty state ───────────────────────────────────────────────────
    if (!questionsReady) {
      return Scaffold(
        backgroundColor: appTheme.scaffoldBackgroundColor,
        appBar: _simpleAppBar(),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.wifi_off_rounded,
                        size: 34, color: accentColor.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Couldn\'t load questions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: fontColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: fontColor.withOpacity(0.5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 180,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => ref.invalidate(duoQuestionsProvider),
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'Try again',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: fontColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Circle',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: fontColor.withOpacity(0.5), size: 22),
            tooltip: 'How it works',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DuoTutorialPage(
                    showDontAskAgain: false,
                    onContinue: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final iconSize   = h < 680 ? 64.0  : h < 800 ? 76.0  : 88.0;
            final iconIcon   = h < 680 ? 32.0  : h < 800 ? 40.0  : 46.0;
            final titleSize  = h < 680 ? 20.0  : h < 800 ? 22.0  : 24.0;
            final gapTop     = h < 680 ? 6.0   : h < 800 ? 10.0  : 16.0;
            final gapMid     = h < 680 ? 8.0   : h < 800 ? 14.0  : 20.0;
            final gapCards   = h < 680 ? 8.0   : 12.0;
            final cardPad    = h < 680 ? 14.0  : h < 800 ? 16.0  : 20.0;
            final btnPadV    = h < 680 ? 11.0  : 14.0;
            final innerGapSm = h < 680 ? 6.0   : 8.0;
            final innerGapMd = h < 680 ? 10.0  : h < 800 ? 12.0  : 16.0;
            final tfFontSize = h < 680 ? 20.0  : 24.0;

            return Column(
              children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: gapTop),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // ── Header ───────────────────────────────────────────────
                  Center(
                    child: CircleModeIcon(
                      size: iconSize,
                      bgColor: accentColor,
                      textColor: accentColor.computeLuminance() > 0.4
                          ? const Color(0xFF100E42)
                          : Colors.white,
                    ),
                  ),
                  SizedBox(height: gapTop),
                  Text(
                    'Circle',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: fontColor,
                      fontWeight: FontWeight.w800,
                      fontSize: titleSize,
                    ),
                  ),
                  SizedBox(height: innerGapSm),
                  Text(
                    'Explore questions together and see where you connect.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: fontColor.withOpacity(0.55),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: gapMid),

                  // ── Start Session card ───────────────────────────────────
                  _SectionCard(
                    padding: cardPad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                color: accentColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Start a Session',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: fontColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: innerGapSm),
                        Text(
                          _maxPlayers == 2
                              ? 'Create and share the code with your partner.'
                              : 'Create and share the code with your group (up to $_maxPlayers players).',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: fontColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: innerGapMd),

                        // ── Group size selector ────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Players',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: fontColor.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [2, 3, 4].map((n) {
                                final isSelected = _maxPlayers == n;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _maxPlayers = n),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accentColor
                                            : accentColor.withOpacity(0.07),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? accentColor
                                              : accentColor.withOpacity(0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        n == 2 ? '2 (Duo)' : '$n',
                                        style: TextStyle(
                                          fontFamily: 'Runtime',
                                          color: isSelected
                                              ? Colors.white
                                              : accentColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),

                        SizedBox(height: innerGapMd),

                        // ── Question count slider ──────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Questions',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    color: fontColor.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$_questionCount',
                                    style: const TextStyle(
                                      fontFamily: 'Runtime',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: accentColor,
                                inactiveTrackColor: accentColor.withOpacity(0.15),
                                thumbColor: accentColor,
                                overlayColor: accentColor.withOpacity(0.12),
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 18),
                              ),
                              child: Slider(
                                value: _questionCount.toDouble().clamp(
                                    5, maxQuestions.toDouble()),
                                min: 5,
                                max: maxQuestions.toDouble(),
                                divisions: maxQuestions - 5,
                                onChanged: (v) =>
                                    setState(() => _questionCount = v.round()),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '5',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    color: fontColor.withOpacity(0.35),
                                    fontSize: 11,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: isPremium
                                      ? null
                                      : () {
                                          final service = ref.read(
                                              subscriptionServiceProvider);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SubscriptionPlansPage(
                                                subscriptionService: service,
                                                onMonthlyPurchase: () =>
                                                    Navigator.pop(context),
                                                onAnnualPurchase: () =>
                                                    Navigator.pop(context),
                                              ),
                                            ),
                                          );
                                        },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isPremium)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 3),
                                          child: Icon(Icons.lock_rounded,
                                              size: 10,
                                              color: fontColor.withOpacity(0.35)),
                                        ),
                                      Text(
                                        isPremium ? '50' : '20 · unlock 50',
                                        style: TextStyle(
                                          fontFamily: 'Runtime',
                                          color: isPremium
                                              ? fontColor.withOpacity(0.35)
                                              : accentColor.withOpacity(0.7),
                                          fontSize: 11,
                                          fontWeight: isPremium
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: innerGapMd),

                        // ── Category filter ────────────────────────────────
                        Builder(builder: (_) {
                          final pool =
                              ref.watch(duoQuestionsProvider).valueOrNull ?? [];
                          return _CategoryFilter(
                            allQuestions: pool,
                            selectedCategories: _selectedCategories,
                            accentColor: accentColor,
                            fontColor: fontColor,
                            onChanged: (cats) =>
                                setState(() => _selectedCategories = cats),
                          );
                        }),

                        SizedBox(height: innerGapMd),

                        // Button or cooldown message
                        if (!isPremium && _cooldownActive) ...[
                          _CooldownWidget(
                            until: _cooldownUntil!,
                            fontColor: fontColor,
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: _isCreating ? null : () => _createSession(isPremium),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: btnPadV),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isCreating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _maxPlayers == 2
                                        ? 'Start with $_questionCount questions'
                                        : 'Start for $_maxPlayers players · $_questionCount questions',
                                    style: const TextStyle(
                                      fontFamily: 'Runtime',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: gapCards),

                  // ── Join Session card ────────────────────────────────────
                  _SectionCard(
                    padding: cardPad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.login_rounded, color: accentColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Join a Session',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: fontColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: innerGapSm),
                        Text(
                          'Enter the 6-character code from your partner.',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: fontColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: innerGapSm + 2),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          enabled: true,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: fontColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            fontSize: tfFontSize,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'XXXXXX',
                            hintStyle: TextStyle(
                              fontFamily: 'Runtime',
                              color: fontColor.withOpacity(0.25),
                              letterSpacing: 6,
                              fontWeight: FontWeight.w800,
                              fontSize: tfFontSize,
                            ),
                            filled: true,
                            fillColor: appTheme.scaffoldBackgroundColor,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: fontColor.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: fontColor.withOpacity(0.2)),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: fontColor.withOpacity(0.1)),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                          ],
                          onSubmitted: (_) => _joinSession(isPremium),
                        ),
                        if (_joinError != null) ...[
                          SizedBox(height: innerGapSm),
                          Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444), size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _joinError!,
                                  style: const TextStyle(
                                    fontFamily: 'Runtime',
                                    color: Color(0xFFEF4444),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: innerGapSm + 2),

                        // Join button — always available
                        ...[
                          ElevatedButton(
                            onPressed: _isJoining ? null : () => _joinSession(isPremium),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: btnPadV),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isJoining
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Join Session',
                                    style: TextStyle(
                                      fontFamily: 'Runtime',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    SizedBox(height: gapCards),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: errorColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: errorColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Runtime',
                                color: errorColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                    ],
                  ),
                ),
              ),
              // ── Past sessions link (pinned, never scrolls away) ───────────
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DuoPastSessionsPage(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: fontColor.withOpacity(0.45),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'View past sessions',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: fontColor.withOpacity(0.45),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Category filter widget ────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final List<dynamic> allQuestions;   // List<Question> — typed as dynamic to avoid import
  final Set<String>? selectedCategories; // null = all
  final Color accentColor;
  final Color fontColor;
  final ValueChanged<Set<String>?> onChanged;

  const _CategoryFilter({
    required this.allQuestions,
    required this.selectedCategories,
    required this.accentColor,
    required this.fontColor,
    required this.onChanged,
  });

  List<String> _uniqueCategories() {
    final seen = <String>{};
    final result = <String>[];
    for (final q in allQuestions) {
      final cat = (q as dynamic).category as String;
      if (seen.add(cat)) result.add(cat);
    }
    result.sort();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _uniqueCategories();
    if (categories.isEmpty) return const SizedBox.shrink();

    final allSelected = selectedCategories == null || selectedCategories!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Categories:',
              style: TextStyle(
                fontFamily: 'Runtime',
                color: fontColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (!allSelected)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Text(
                  'All',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: accentColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: categories.map((cat) {
            final isSelected = allSelected || selectedCategories!.contains(cat);
            return GestureDetector(
              onTap: () {
                // Toggle this category
                final current = selectedCategories == null
                    ? Set<String>.from(categories) // start with all
                    : Set<String>.from(selectedCategories!);
                if (isSelected) {
                  current.remove(cat);
                } else {
                  current.add(cat);
                }
                // If all are selected, collapse back to null (= all)
                if (current.length == categories.length) {
                  onChanged(null);
                } else if (current.isEmpty) {
                  // Can't have zero — revert
                  onChanged(null);
                } else {
                  onChanged(current);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor
                      : accentColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : accentColor.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color:
                        isSelected ? Colors.white : accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Cooldown info widget ──────────────────────────────────────────────────────

class _CooldownWidget extends StatelessWidget {
  final DateTime until;
  final Color fontColor;
  final String message;

  const _CooldownWidget({
    required this.until,
    required this.fontColor,
    this.message = '',
  });

  @override
  Widget build(BuildContext context) {
    final remaining = until.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final timeText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    const amberColor = Color(0xFFF59E0B);
    final displayMsg = message.isNotEmpty
        ? '$message — available in $timeText'
        : 'Circle on cooldown — available in $timeText';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: amberColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amberColor.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: amberColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayMsg,
                  style: const TextStyle(
                    fontFamily: 'Runtime',
                    color: amberColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upgrade to premium for unlimited Circle sessions',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: fontColor.withOpacity(0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final double padding;
  const _SectionCard({required this.child, this.padding = 20});

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: appTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
