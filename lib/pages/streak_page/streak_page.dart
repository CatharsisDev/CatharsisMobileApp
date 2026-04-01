import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/streak_provider.dart';
import '../../provider/theme_provider.dart';
import '../../services/subscription_service.dart';

List<_DayInfo> buildWeek(List<String> activeDates) {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  const abbrs = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  return List.generate(7, (i) {
    final day = monday.add(Duration(days: i));
    final ds =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isFuture = !isToday &&
        DateTime(day.year, day.month, day.day)
            .isAfter(DateTime(now.year, now.month, now.day));
    return _DayInfo(
      abbr: abbrs[i],
      dateStr: ds,
      active: activeDates.contains(ds),
      isToday: isToday,
      isFuture: isFuture,
    );
  });
}

// =============================================================================
// StreakPage — shown when the user TAPS the flame icon on the home screen.
// Uses the app theme (not hardcoded dark) and shows a full weekly overview.
// =============================================================================

class StreakPage extends ConsumerStatefulWidget {
  const StreakPage({Key? key}) : super(key: key);

  @override
  ConsumerState<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends ConsumerState<StreakPage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  late final AnimationController _wiggleCtrl;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _rotateAnim = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _wiggleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _wiggleCtrl.dispose();
    super.dispose();
  }

  String _message(int streak, {required bool swipedToday}) {
    if (streak == 0) return 'Swipe a card today to start your streak!';
    if (!swipedToday) return "You haven't swiped yet today — keep your streak alive!";
    if (streak == 1) return 'Day one! Every journey starts somewhere.';
    if (streak < 7) return 'Keep the momentum going!';
    if (streak < 14) return "One week strong! You're building a habit.";
    if (streak < 30) return "That's another step closer to your goals. Great job!";
    return "Incredible dedication — you're unstoppable!";
  }

  String _emoji(int streak, {required bool swipedToday}) {
    if (streak == 0) return '🌱';
    if (!swipedToday) return '⏳';
    if (streak == 1) return '🌟';
    if (streak < 7) return '💪';
    if (streak < 14) return '🎯';
    if (streak < 30) return '🎉';
    return '🏆';
  }

  @override
  Widget build(BuildContext context) {
    final streakData = ref.watch(streakProvider);
    final streak = streakData.current;
    final longest = streakData.longest;
    final week = buildWeek(streakData.activeDates);
    final freezes = streakData.freezesAvailable;
    final swipedToday = week.any((d) => d.isToday && d.active);
    final isPremium = ref.watch(subscriptionServiceProvider).isPremium.value;

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final fontColor = customTheme?.fontColor ?? theme.textTheme.titleLarge?.color ?? Colors.black87;
    final cardColor = theme.cardColor;
    final dividerColor = isDark ? Colors.white12 : Colors.grey[200]!;
    final motivCardBg = customTheme?.preferenceModalBackgroundColor.withOpacity(0.85)
        ?? (isDark ? Colors.white10 : Colors.black.withOpacity(0.06));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          image: (customTheme?.showBackgroundTexture ?? false) &&
                  customTheme?.backgroundImagePath != null
              ? DecorationImage(
                  image: AssetImage(customTheme!.backgroundImagePath!),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                )
              : null,
        ),
        child: Column(
        children: [
          // ── Themed header (replaces purple gradient) ──────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back_ios,
                          color: customTheme?.iconColor ?? fontColor, size: 22),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$streak',
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  fontSize: 84,
                                  fontWeight: FontWeight.bold,
                                  color: fontColor,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Day Streak',
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: fontColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Animated flame icon with glow
                        AnimatedBuilder(
                          animation:
                              Listenable.merge([_pulseCtrl, _wiggleCtrl]),
                          builder: (context, child) => Transform.rotate(
                            angle: _rotateAnim.value,
                            child: Transform.scale(
                              scale: _scaleAnim.value,
                              child: child,
                            ),
                          ),
                          child: _FlameIcon(
                            size: 80,
                            brightness: swipedToday ? 1.0 : 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Motivational card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: motivCardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (customTheme?.preferenceBorderColor ?? Colors.grey).withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(_emoji(streak, swipedToday: swipedToday),
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message(streak, swipedToday: swipedToday),
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontSize: 15,
                                color: fontColor,
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

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Overview
                  Text(
                    'My Overview',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: week.map((d) {
                        Color labelColor;
                        if (d.isToday) {
                          labelColor = Colors.orange;
                        } else if (d.isFuture) {
                          labelColor = isDark
                              ? Colors.grey[700]!
                              : Colors.grey[300]!;
                        } else {
                          labelColor = isDark
                              ? Colors.grey[400]!
                              : Colors.grey[600]!;
                        }

                        Widget flameWidget;
                        if (d.active) {
                          flameWidget = ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (b) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFED40), Color(0xFFFF4500)],
                            ).createShader(b),
                            child: const Icon(
                              Icons.local_fire_department,
                              size: 28,
                              color: Colors.white,
                            ),
                          );
                        } else if (d.isFuture) {
                          flameWidget = Icon(
                            Icons.local_fire_department,
                            size: 28,
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                          );
                        } else {
                          flameWidget = Icon(
                            Icons.local_fire_department,
                            size: 28,
                            color: isDark
                                ? Colors.grey[700]
                                : Colors.grey[300],
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              d.abbr,
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: labelColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            flameWidget,
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // My Summary
                  Text(
                    'My Summary',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                          icon: Icons.local_fire_department,
                          iconColor: const Color(0xFFFF8C00),
                          label: 'Current streak',
                          value: '$streak days',
                          showDivider: true,
                          dividerColor: dividerColor,
                          theme: theme,
                        ),
                        _SummaryRow(
                          icon: Icons.emoji_events,
                          iconColor: const Color(0xFFFFD700),
                          label: 'Longest streak',
                          value: '$longest days',
                          showDivider: true,
                          dividerColor: dividerColor,
                          theme: theme,
                        ),
                        if (isPremium)
                          _SummaryRow(
                            icon: Icons.ac_unit,
                            iconColor: const Color(0xFF64B5F6),
                            label: 'Streak freezes',
                            value: '$freezes / 2 this week',
                            showDivider: false,
                            dividerColor: dividerColor,
                            theme: theme,
                          )
                        else
                          _SummaryRow(
                            icon: Icons.ac_unit,
                            iconColor: Colors.grey,
                            label: 'Streak freezes',
                            value: 'Premium only',
                            showDivider: false,
                            dividerColor: dividerColor,
                            theme: theme,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Close button ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      customTheme?.preferenceButtonColor ?? const Color(0xFF7C3AED),
                  foregroundColor: customTheme?.buttonFontColor ?? Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  "I'm Committed",
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: customTheme?.buttonFontColor ?? Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
        ), // Container
      ),
    );
  }
}

// =============================================================================
// StreakCelebrationPage — auto-shown after the first streak-increasing swipe
// of the day. Dark full-screen overlay with flame light-up animation and
// Duolingo-style week progress bar.
// =============================================================================

class StreakCelebrationPage extends ConsumerStatefulWidget {
  const StreakCelebrationPage({Key? key}) : super(key: key);

  @override
  ConsumerState<StreakCelebrationPage> createState() =>
      _StreakCelebrationPageState();
}

class _StreakCelebrationPageState extends ConsumerState<StreakCelebrationPage>
    with TickerProviderStateMixin {
  // Entry (runs once)
  late final AnimationController _entryCtrl;
  late final Animation<double> _flameScale;
  late final Animation<double> _flameBrightness;
  late final Animation<double> _contentFade;
  late final Animation<double> _barDraw;

  // Continuous flicker (after entry)
  late final AnimationController _flickerCtrl;
  late final Animation<double> _flickerScale;
  late final Animation<double> _flickerAngle;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _flameScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_entryCtrl);

    _flameBrightness = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.60, curve: Curves.easeIn),
    );

    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.40, 0.90, curve: Curves.easeOut),
    );

    _barDraw = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _flickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _flickerScale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut),
    );
    _flickerAngle = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl.forward().then((_) {
      if (mounted) _flickerCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _flickerCtrl.dispose();
    super.dispose();
  }

  String _message(int streak) {
    if (streak == 0) return 'Swipe a card today to\nstart your streak!';
    if (streak == 1) return 'Day one!\nEvery journey starts somewhere.';
    if (streak < 7) return 'Keep the\nmomentum going!';
    if (streak < 14) return "One week strong!\nYou're building a habit.";
    if (streak < 30) return "That's another step closer\nto your goals. Great job!";
    return "Incredible dedication —\nyou're unstoppable!";
  }

  @override
  Widget build(BuildContext context) {
    final streakData = ref.watch(streakProvider);
    final streak = streakData.current;
    final longest = streakData.longest;
    final week = buildWeek(streakData.activeDates);
    final todayIdx = week.indexWhere((d) => d.isToday).clamp(0, 6);

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final fontColor = customTheme?.fontColor ?? theme.textTheme.titleLarge?.color ?? Colors.black87;
    final mutedColor = Color.lerp(fontColor, bgColor, 0.45) ?? fontColor.withOpacity(0.55);
    final chipBg = customTheme?.profileContentBackgroundColor ?? theme.cardColor;
    final chipBorder = (customTheme?.preferenceBorderColor ?? Colors.grey).withOpacity(0.2);
    final barContainerBg = customTheme?.preferenceModalBackgroundColor.withOpacity(0.55)
        ?? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04));
    final barContainerBorder = (customTheme?.preferenceBorderColor ?? Colors.grey).withOpacity(isDark ? 0.2 : 0.12);
    final btnBg = customTheme?.preferenceButtonColor ?? const Color(0xFF7C3AED);
    final btnFg = customTheme?.buttonFontColor ?? Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          image: (customTheme?.showBackgroundTexture ?? false) &&
                  customTheme?.backgroundImagePath != null
              ? DecorationImage(
                  image: AssetImage(customTheme!.backgroundImagePath!),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios,
                        color: customTheme?.iconColor ?? fontColor, size: 22),
                  ),
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Animated flame
                    AnimatedBuilder(
                      animation:
                          Listenable.merge([_entryCtrl, _flickerCtrl]),
                      builder: (context, child) {
                        final scale = _flameScale.value *
                            (_flickerCtrl.isAnimating
                                ? _flickerScale.value
                                : 1.0);
                        final angle = _flickerCtrl.isAnimating
                            ? _flickerAngle.value
                            : 0.0;
                        return Transform.rotate(
                          angle: angle,
                          child: Transform.scale(
                            scale: scale,
                            child: _FlameIcon(
                              size: 140,
                              brightness: _flameBrightness.value,
                            ),
                          ),
                        );
                      },
                    ),

                    // Streak number + label
                    FadeTransition(
                      opacity: _contentFade,
                      child: Column(
                        children: [
                          Text(
                            '$streak',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 82,
                              fontWeight: FontWeight.bold,
                              color: fontColor,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Day Streak',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: fontColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Week progress bar
                    FadeTransition(
                      opacity: _contentFade,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          decoration: BoxDecoration(
                            color: barContainerBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: barContainerBorder),
                          ),
                          child: AnimatedBuilder(
                            animation: _barDraw,
                            builder: (context, _) => _WeekProgressBar(
                              days: week,
                              todayIndex: todayIdx,
                              progress: _barDraw.value,
                              labelColor: fontColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Motivational message
                    FadeTransition(
                      opacity: _contentFade,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _message(streak),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 16,
                            color: mutedColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // Stat chips
                    FadeTransition(
                      opacity: _contentFade,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                label: 'Current streak',
                                value: streak,
                                icon: Icons.local_fire_department,
                                iconColor: const Color(0xFFFF8C00),
                                bgColor: chipBg,
                                borderColor: chipBorder,
                                fontColor: fontColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatChip(
                                label: 'Longest streak',
                                value: longest,
                                icon: Icons.emoji_events,
                                iconColor: const Color(0xFFFFD700),
                                bgColor: chipBg,
                                borderColor: chipBorder,
                                fontColor: fontColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // "I'm Committed" button
              FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnBg,
                        foregroundColor: btnFg,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32)),
                        elevation: 0,
                      ),
                      child: Text(
                        "I'm Committed",
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: btnFg,
                        ),
                      ),
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
}

// =============================================================================
// Flame icon — ShaderMask gradient, animates from unlit → lit
// =============================================================================

class _FlameIcon extends StatelessWidget {
  final double size;
  final double brightness; // 0.0 = dark · 1.0 = fully lit

  const _FlameIcon({required this.size, this.brightness = 1.0});

  @override
  Widget build(BuildContext context) {
    final t = brightness.clamp(0.0, 1.0);
    final top = Color.lerp(const Color(0xFF2A2A2A), const Color(0xFFFFED40), t)!;
    final mid = Color.lerp(const Color(0xFF1A1A1A), const Color(0xFFFF8C00), t)!;
    final bot = Color.lerp(const Color(0xFF0D0D0D), const Color(0xFFFF4500), t)!;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (t > 0.1)
          Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8C00).withOpacity(0.35 * t),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, mid, bot],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: Icon(Icons.local_fire_department, size: size, color: Colors.white),
        ),
      ],
    );
  }
}

// =============================================================================
// Week progress bar — Duolingo-style (used in StreakCelebrationPage)
// =============================================================================

class _WeekProgressBar extends StatelessWidget {
  final List<_DayInfo> days;
  final int todayIndex;
  final double progress;
  final Color labelColor;

  const _WeekProgressBar({
    required this.days,
    required this.todayIndex,
    this.progress = 1.0,
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(7, (i) {
            final d = days[i];
            final alpha = d.isToday ? 1.0 : d.isFuture ? 0.25 : 0.55;
            return Expanded(
              child: Text(
                d.abbr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: labelColor.withOpacity(alpha),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 28,
            width: constraints.maxWidth,
            child: CustomPaint(
              painter: _BarPainter(
                days: days,
                todayIndex: todayIndex,
                progress: progress,
                trackColor: labelColor.withOpacity(0.15),
                inactiveDotColor: labelColor.withOpacity(0.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<_DayInfo> days;
  final int todayIndex;
  final double progress;
  final Color trackColor;
  final Color inactiveDotColor;

  const _BarPainter({
    required this.days,
    required this.todayIndex,
    required this.progress,
    this.trackColor = const Color(0x1FFFFFFF),
    this.inactiveDotColor = const Color(0x33FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 7;
    const barCY = 10.0;
    const barH = 6.0;

    final startX = cellW * 0.5;
    final fullEndX = cellW * (todayIndex + 0.5);
    final animEndX = startX + (fullEndX - startX) * progress;

    // Track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, barCY - barH / 2, cellW * 6, barH),
        const Radius.circular(3),
      ),
      Paint()..color = trackColor,
    );

    // Gold bar (animated)
    final barWidth = animEndX - startX;
    if (barWidth > 0) {
      final barRect = Rect.fromLTWH(startX, barCY - barH / 2, barWidth, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFB800), Color(0xFFFFE040)],
          ).createShader(barRect),
      );
    }

    // Markers
    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      final cx = cellW * (i + 0.5);
      if (d.isToday) {
        final alpha = ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
        if (alpha > 0) {
          _drawSparkle(canvas, Offset(cx, barCY), 9,
              Colors.white.withOpacity(alpha));
        }
      } else if (!d.isFuture) {
        canvas.drawCircle(
          Offset(cx, barCY),
          d.active ? 4.5 : 3.5,
          Paint()
            ..color = d.active
                ? const Color(0xFFFFB800)
                : inactiveDotColor,
        );
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r * 2.2,
      Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.38, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.38, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(c.dx - r, c.dy), Offset(c.dx - r * 0.4, c.dy), stroke);
    canvas.drawLine(
        Offset(c.dx + r * 0.4, c.dy), Offset(c.dx + r, c.dy), stroke);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress ||
      old.todayIndex != todayIndex ||
      old.trackColor != trackColor;
}

// =============================================================================
// Stat chip (used in StreakCelebrationPage)
// =============================================================================

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final Color fontColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.bgColor = const Color(0x12FFFFFF),
    this.borderColor = const Color(0x1AFFFFFF),
    this.fontColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fontColor.withOpacity(0.45),
                  fontSize: 10,
                  fontFamily: 'Runtime',
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  color: fontColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Runtime',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Summary row (used in StreakPage info view)
// =============================================================================

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool showDivider;
  final Color dividerColor;
  final ThemeData theme;

  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.showDivider,
    required this.dividerColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: dividerColor, indent: 16, endIndent: 16),
      ],
    );
  }
}

// =============================================================================
// StreakFreezePage — auto-shown on app open when a freeze was consumed
// to protect the streak while the user was inactive.
// =============================================================================

class StreakFreezePage extends ConsumerStatefulWidget {
  const StreakFreezePage({Key? key}) : super(key: key);

  @override
  ConsumerState<StreakFreezePage> createState() => _StreakFreezePageState();
}

class _StreakFreezePageState extends ConsumerState<StreakFreezePage>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentFade;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_entryCtrl);
    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.40, 0.95, curve: Curves.easeOut),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.10)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward().then((_) {
      if (mounted) _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streakData = ref.watch(streakProvider);
    final streak = streakData.current;
    final freezesLeft = streakData.freezesAvailable;

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final fontColor = customTheme?.fontColor ?? theme.textTheme.titleLarge?.color ?? Colors.black87;
    final mutedColor = Color.lerp(fontColor, bgColor, 0.45) ?? fontColor.withOpacity(0.55);
    final chipBg = customTheme?.profileContentBackgroundColor ?? theme.cardColor;
    final chipBorder = (customTheme?.preferenceBorderColor ?? Colors.grey).withOpacity(0.2);
    final btnBg = customTheme?.preferenceButtonColor ?? const Color(0xFF7C3AED);
    final btnFg = customTheme?.buttonFontColor ?? Colors.white;

    // Ice-blue snowflake colours
    const snowTop    = Color(0xFFB3E5FC);
    const snowMid    = Color(0xFF42A5F5);
    const snowBottom = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          image: (customTheme?.showBackgroundTexture ?? false) &&
                  customTheme?.backgroundImagePath != null
              ? DecorationImage(
                  image: AssetImage(customTheme!.backgroundImagePath!),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close,
                        color: customTheme?.iconColor ?? fontColor, size: 24),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Animated snowflake icon
                      AnimatedBuilder(
                        animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
                        builder: (context, _) {
                          final scale = _iconScale.value *
                              (_pulseCtrl.isAnimating ? _pulseScale.value : 1.0);
                          return Transform.scale(
                            scale: scale,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow
                                Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: snowMid.withOpacity(0.35 * _iconScale.value),
                                        blurRadius: 50,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [snowTop, snowMid, snowBottom],
                                  ).createShader(bounds),
                                  child: const Icon(
                                    Icons.ac_unit,
                                    size: 120,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Title
                      FadeTransition(
                        opacity: _contentFade,
                        child: Text(
                          'Streak Protected!',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: fontColor,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 8),

                      FadeTransition(
                        opacity: _contentFade,
                        child: Text(
                          'A streak freeze kept your $streak-day\nstreak alive while you were away.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 15,
                            color: mutedColor,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Freeze chips
                      FadeTransition(
                        opacity: _contentFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatChip(
                                  label: 'Streak kept alive',
                                  value: streak,
                                  icon: Icons.local_fire_department,
                                  iconColor: const Color(0xFFFF8C00),
                                  bgColor: chipBg,
                                  borderColor: chipBorder,
                                  fontColor: fontColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatChip(
                                  label: 'Freezes left',
                                  value: freezesLeft,
                                  icon: Icons.ac_unit,
                                  iconColor: snowMid,
                                  bgColor: chipBg,
                                  borderColor: chipBorder,
                                  fontColor: fontColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      FadeTransition(
                        opacity: _contentFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: snowMid.withOpacity(isDark ? 0.12 : 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: snowMid.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Color(0xFF42A5F5), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You get 2 streak freezes per week with your subscription.',
                                    style: TextStyle(
                                      fontFamily: 'Runtime',
                                      fontSize: 13,
                                      color: mutedColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 0, 24, MediaQuery.of(context).padding.bottom + 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnBg,
                        foregroundColor: btnFg,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Keep Going!",
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: btnFg,
                        ),
                      ),
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
}

// =============================================================================
// StreakLostPage — auto-shown on app open when a streak was broken because
// the user ran out of freezes or was inactive for too long.
// =============================================================================

class StreakLostPage extends ConsumerStatefulWidget {
  const StreakLostPage({Key? key}) : super(key: key);

  @override
  ConsumerState<StreakLostPage> createState() => _StreakLostPageState();
}

class _StreakLostPageState extends ConsumerState<StreakLostPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentFade;
  late final AnimationController _flickerCtrl;
  late final Animation<double> _flickerOpacity;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_entryCtrl);
    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.40, 0.95, curve: Curves.easeOut),
    );
    _flickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _flickerOpacity = Tween<double>(begin: 0.5, end: 0.85)
        .animate(CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward().then((_) {
      if (mounted) _flickerCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _flickerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final fontColor = customTheme?.fontColor ?? theme.textTheme.titleLarge?.color ?? Colors.black87;
    final mutedColor = Color.lerp(fontColor, bgColor, 0.45) ?? fontColor.withOpacity(0.55);
    final chipBg = customTheme?.profileContentBackgroundColor ?? theme.cardColor;
    final chipBorder = (customTheme?.preferenceBorderColor ?? Colors.grey).withOpacity(0.2);
    final btnBg = customTheme?.preferenceButtonColor ?? const Color(0xFF7C3AED);
    final btnFg = customTheme?.buttonFontColor ?? Colors.white;

    // Dimmed flame colours for "lost" state
    const lostTop = Color(0xFF9E9E9E);
    const lostMid = Color(0xFF616161);
    const lostBot = Color(0xFF424242);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          image: (customTheme?.showBackgroundTexture ?? false) &&
                  customTheme?.backgroundImagePath != null
              ? DecorationImage(
                  image: AssetImage(customTheme!.backgroundImagePath!),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close,
                        color: customTheme?.iconColor ?? fontColor, size: 24),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Dimmed / extinguished flame icon
                      AnimatedBuilder(
                        animation: Listenable.merge([_entryCtrl, _flickerCtrl]),
                        builder: (context, _) {
                          final opacity = _flickerCtrl.isAnimating
                              ? _flickerOpacity.value
                              : 1.0;
                          return Transform.scale(
                            scale: _iconScale.value,
                            child: Opacity(
                              opacity: opacity,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Subtle grey glow
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(
                                              0.15 * _iconScale.value),
                                          blurRadius: 40,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [lostTop, lostMid, lostBot],
                                    ).createShader(bounds),
                                    child: const Icon(
                                      Icons.local_fire_department,
                                      size: 120,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      FadeTransition(
                        opacity: _contentFade,
                        child: Text(
                          'Streak Lost',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: fontColor,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 10),

                      FadeTransition(
                        opacity: _contentFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Text(
                            "Don't give up — every champion\nstarts again from day one.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 15,
                              color: mutedColor,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Info card about freezes
                      FadeTransition(
                        opacity: _contentFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: (customTheme?.profileContentBackgroundColor
                                      ?? theme.cardColor),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (customTheme?.preferenceBorderColor ??
                                        Colors.grey)
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.ac_unit,
                                        color: Color(0xFF42A5F5), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Protect your next streak',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: fontColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Subscribers get 2 streak freezes per week. '
                                  'A freeze automatically kicks in when you miss '
                                  'a day, keeping your streak alive.',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 13,
                                    color: mutedColor,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 0, 24, MediaQuery.of(context).padding.bottom + 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnBg,
                        foregroundColor: btnFg,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Start Fresh",
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: btnFg,
                        ),
                      ),
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
}

// =============================================================================
// Shared data class
// =============================================================================

class _DayInfo {
  final String abbr;
  final String dateStr;
  final bool active;
  final bool isToday;
  final bool isFuture;

  const _DayInfo({
    required this.abbr,
    required this.dateStr,
    required this.active,
    required this.isToday,
    required this.isFuture,
  });
}
