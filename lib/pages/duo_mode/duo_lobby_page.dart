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
import '../../provider/app_state_provider.dart';
import '../../services/duo_session_service.dart';
import '../../services/subscription_service.dart';
import '../subscription_plans/subscription_plans_page.dart';
import 'duo_past_sessions_page.dart';

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

  Future<void> _createSession(bool isPremium) async {
    // Guard: non-premium users must wait out their cooldown
    if (!isPremium && _cooldownActive) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not logged in');

      final cardState = ref.read(cardStateProvider);
      final questions = cardState.sessionQuestions.isNotEmpty
          ? cardState.sessionQuestions
          : cardState.allQuestions;

      if (questions.isEmpty) throw Exception('No cards available. Please wait and try again.');

      final displayName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email?.split('@').first ?? 'Host';

      // Clamp count for non-premium
      final count = (!isPremium && _questionCount > 10) ? 10 : _questionCount;

      final code = await DuoSessionService.createSession(
        hostUid: user.uid,
        hostName: displayName,
        questions: questions.take(count).toList(),
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
    // Guard: non-premium users must wait out their cooldown
    if (!isPremium && _cooldownActive) return;

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

      final displayName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email?.split('@').first ?? 'Guest';

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

    // If non-premium and current count is above the limit, reset it
    if (!isPremium && _questionCount > 10) {
      Future.microtask(() {
        if (mounted) setState(() => _questionCount = 10);
      });
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
          'Duo Mode',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
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

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: gapTop),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ───────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.people_rounded, size: iconIcon, color: accentColor),
                    ),
                  ),
                  SizedBox(height: gapTop),
                  Text(
                    'Duo Mode',
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
                          'Create and share the code with your partner.',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: fontColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: innerGapMd),

                        // ── Question count picker ──────────────────────────
                        Row(
                          children: [
                            Text(
                              'Questions:',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: fontColor.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [5, 10, 15, 20].map((n) {
                                  // Non-premium users can only pick 5 or 10
                                  final isLocked = !isPremium && n > 10;
                                  final selected = _questionCount == n && !isLocked;

                                  return GestureDetector(
                                    onTap: () {
                                      if (isLocked) {
                                        // Take the user straight to the paywall
                                        final service = ref.read(subscriptionServiceProvider);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SubscriptionPlansPage(
                                              subscriptionService: service,
                                              onMonthlyPurchase: () => Navigator.pop(context),
                                              onAnnualPurchase:  () => Navigator.pop(context),
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() => _questionCount = n);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 44,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isLocked
                                            ? fontColor.withOpacity(0.04)
                                            : selected
                                                ? accentColor
                                                : accentColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isLocked
                                              ? fontColor.withOpacity(0.10)
                                              : selected
                                                  ? accentColor
                                                  : accentColor.withOpacity(0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: isLocked
                                            ? Icon(Icons.lock_rounded,
                                                size: 14,
                                                color: fontColor.withOpacity(0.25))
                                            : Text(
                                                '$n',
                                                style: TextStyle(
                                                  fontFamily: 'Runtime',
                                                  color: selected
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
                            ),
                          ],
                        ),

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
                                    'Start with $_questionCount questions',
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
                          enabled: isPremium || !_cooldownActive,
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

                        // Button or cooldown message
                        if (!isPremium && _cooldownActive) ...[
                          _CooldownWidget(
                            until: _cooldownUntil!,
                            fontColor: fontColor,
                            message: 'Cooldown active — can\'t join yet',
                          ),
                        ] else ...[
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

                  // ── Past sessions link ────────────────────────────────────
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DuoPastSessionsPage(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
              ),
            );
          },
        ),
      ),
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
        : 'Duo Mode on cooldown — available in $timeText';

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
                  'Upgrade to premium for unlimited duo sessions',
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
