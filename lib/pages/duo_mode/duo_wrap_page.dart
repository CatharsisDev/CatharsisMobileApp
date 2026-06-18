import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/duo_session.dart';
import '../../provider/duo_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────────────────────

class DuoWrapPage extends ConsumerWidget {
  final String sessionCode;
  const DuoWrapPage({Key? key, required this.sessionCode}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(duoSessionStreamProvider(sessionCode));
    return sessionAsync.when(
      loading: () => const _LoadingScaffold(),
      error: (_, __) => const _LoadingScaffold(),
      data: (session) {
        if (session == null) return const _LoadingScaffold();
        return _WrapSlideShow(
          session: session,
          onFinish: () =>
              context.pushReplacement('/duo/summary/$sessionCode'),
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFF07001A),
        body: Center(child: CircularProgressIndicator(color: Colors.white38)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide data
// ─────────────────────────────────────────────────────────────────────────────

enum _SlideType { opener, connection, matchRate, topCategory, differed, outro }

class _SlideData {
  final _SlideType type;
  final int primaryValue;
  final String headline;
  final String detail;   // secondary line
  final String tag;      // small top label

  const _SlideData({
    required this.type,
    required this.primaryValue,
    required this.headline,
    this.detail = '',
    this.tag = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide-show controller
// ─────────────────────────────────────────────────────────────────────────────

class _WrapSlideShow extends StatefulWidget {
  final DuoSession session;
  final VoidCallback onFinish;
  const _WrapSlideShow({required this.session, required this.onFinish});

  @override
  State<_WrapSlideShow> createState() => _WrapSlideShowState();
}

class _WrapSlideShowState extends State<_WrapSlideShow>
    with SingleTickerProviderStateMixin {
  int _page = 0;
  int _prevPage = 0;
  late List<_SlideData> _slides;

  // Background cross-fade controller
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _slides = _buildSlides(widget.session);
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bgAnim =
        CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  static List<_SlideData> _buildSlides(DuoSession session) {
    final total    = session.cards.length;
    final matched  = session.matchedCards.length;
    final differed = session.splitCards.length;
    final pct      = total > 0 ? ((matched / total) * 100).round() : 0;
    final partner  = session.guestName ?? 'Partner';
    final topCat   = _topCategory(session.matchedCards);

    return [
      _SlideData(
        type: _SlideType.opener,
        primaryValue: total,
        tag: '${session.hostName} & $partner',
        headline: 'Your\nDuo Recap',
        detail: total == 1 ? 'question explored' : 'questions explored',
      ),
      _SlideData(
        type: _SlideType.connection,
        primaryValue: matched,
        tag: 'Moments together',
        headline: matched == 0
            ? 'Keep exploring'
            : matched == 1
                ? 'One connection'
                : '$matched connections',
        detail: 'out of $total questions',
      ),
      _SlideData(
        type: _SlideType.matchRate,
        primaryValue: pct,
        tag: 'Match rate',
        headline: '$pct%',
        detail: _rateCaption(pct),
      ),
      if (topCat != null && matched > 1)
        _SlideData(
          type: _SlideType.topCategory,
          primaryValue: matched,
          tag: 'Your strongest bond',
          headline: topCat,
          detail: 'Most connections happened here.',
        ),
      if (differed > 0)
        _SlideData(
          type: _SlideType.differed,
          primaryValue: differed,
          tag: 'Different perspectives',
          headline: differed == 1 ? '1 difference' : '$differed differences',
          detail: 'Different views deepen real conversation.',
        ),
      const _SlideData(
        type: _SlideType.outro,
        primaryValue: 0,
        headline: 'Every question\nbrings you\ncloser.',
      ),
    ];
  }

  static String? _topCategory(List<DuoCard> matched) {
    if (matched.isEmpty) return null;
    final counts = <String, int>{};
    for (final c in matched) {
      counts[c.questionCategory] = (counts[c.questionCategory] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _rateCaption(int pct) {
    if (pct >= 80) return 'Deeply in sync.';
    if (pct >= 60) return 'A strong emotional connection.';
    if (pct >= 40) return 'You see the world in different, beautiful ways.';
    if (pct >  0 ) return 'Every conversation deepens the bond.';
    return 'Keep exploring — connection takes time.';
  }

  void _advance() {
    if (_page >= _slides.length - 1) {
      widget.onFinish();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _prevPage = _page;
      _page++;
    });
    _bgCtrl.forward(from: 0);
  }

  // ── Background colour pairs per slide type ──────────────────────────────
  static const _bgColors = <_SlideType, List<Color>>{
    _SlideType.opener:      [Color(0xFF07001A), Color(0xFF13003A)],
    _SlideType.connection:  [Color(0xFF001210), Color(0xFF002A1C)],
    _SlideType.matchRate:   [Color(0xFF000A1E), Color(0xFF001040)],
    _SlideType.topCategory: [Color(0xFF100400), Color(0xFF220900)],
    _SlideType.differed:    [Color(0xFF0F0010), Color(0xFF1E0025)],
    _SlideType.outro:       [Color(0xFF030008), Color(0xFF08001C)],
  };

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    final prev  = _slides[_prevPage];

    final prevColors = _bgColors[prev.type]!;
    final nextColors = _bgColors[slide.type]!;

    return GestureDetector(
      onTap: slide.type == _SlideType.outro ? null : _advance,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, _) {
          final t    = _bgAnim.value;
          final top  = Color.lerp(prevColors[0], nextColors[0], t)!;
          final bot  = Color.lerp(prevColors[1], nextColors[1], t)!;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, bot],
              ),
            ),
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Decorative orb layer ─────────────────────────────────
                  _OrbLayer(type: slide.type),

                  // ── Progress bar ─────────────────────────────────────────
                  Positioned(
                    top: 16, left: 24, right: 24,
                    child: _ProgressBar(
                      count: _slides.length,
                      current: _page,
                    ),
                  ),

                  // ── Slide content (cross-fades on page change) ───────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                              parent: anim, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_page),
                      child: _buildSlide(slide),
                    ),
                  ),

                  // ── Tap hint ─────────────────────────────────────────────
                  if (slide.type != _SlideType.outro)
                    const Positioned(
                      bottom: 28, left: 0, right: 0,
                      child: Center(child: _TapHint()),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlide(_SlideData d) {
    switch (d.type) {
      case _SlideType.opener:      return _OpenerSlide(data: d);
      case _SlideType.connection:  return _ConnectionSlide(data: d);
      case _SlideType.matchRate:   return _MatchRateSlide(data: d);
      case _SlideType.topCategory: return _CategorySlide(data: d);
      case _SlideType.differed:    return _DifferedSlide(data: d);
      case _SlideType.outro:
        return _OutroSlide(data: d, onFinish: widget.onFinish);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Decorative orb layer (glowing radial gradients per slide)
// ─────────────────────────────────────────────────────────────────────────────

class _OrbLayer extends StatelessWidget {
  final _SlideType type;
  const _OrbLayer({required this.type});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: _orbs(),
    );
  }

  List<Widget> _orbs() {
    switch (type) {
      case _SlideType.opener:
        return [
          _orb(560, const Color(0xFF7B2FFF), 0.28,
              alignment: const Alignment(1.1, -0.9)),
          _orb(400, const Color(0xFF3F1FCC), 0.22,
              alignment: const Alignment(-1.2, 0.7)),
          _orb(250, const Color(0xFFFF2F88), 0.12,
              alignment: const Alignment(0.2, 0.1)),
        ];
      case _SlideType.connection:
        return [
          _orb(600, const Color(0xFF00FF88), 0.10,
              alignment: const Alignment(0.0, -0.8)),
          _orb(420, const Color(0xFF00CC55), 0.12,
              alignment: const Alignment(1.2, 0.6)),
          _orb(300, const Color(0xFF00FFCC), 0.07,
              alignment: const Alignment(-1.1, 0.2)),
        ];
      case _SlideType.matchRate:
        return [
          _orb(580, const Color(0xFF0066FF), 0.20,
              alignment: const Alignment(-0.8, -0.8)),
          _orb(450, const Color(0xFF7B00FF), 0.16,
              alignment: const Alignment(1.1, 0.6)),
          _orb(280, const Color(0xFF00AAFF), 0.10,
              alignment: const Alignment(0.3, -0.1)),
        ];
      case _SlideType.topCategory:
        return [
          _orb(560, const Color(0xFFFF6600), 0.22,
              alignment: const Alignment(0.8, -1.0)),
          _orb(400, const Color(0xFFFF3300), 0.16,
              alignment: const Alignment(-1.1, 0.5)),
          _orb(250, const Color(0xFFFFAA00), 0.10,
              alignment: const Alignment(-0.2, -0.3)),
        ];
      case _SlideType.differed:
        return [
          _orb(500, const Color(0xFFCC0044), 0.22,
              alignment: const Alignment(-1.0, -0.5)),
          _orb(460, const Color(0xFF9900CC), 0.20,
              alignment: const Alignment(1.1, 0.7)),
          _orb(240, const Color(0xFFFF0066), 0.10,
              alignment: const Alignment(0.1, 0.1)),
        ];
      case _SlideType.outro:
        return [
          _orb(500, const Color(0xFF6600CC), 0.20,
              alignment: const Alignment(-0.5, -0.9)),
          _orb(380, const Color(0xFF0044CC), 0.14,
              alignment: const Alignment(1.1, 0.2)),
          _orb(280, const Color(0xFFCC0066), 0.10,
              alignment: const Alignment(0.7, 1.0)),
          _orb(160, const Color(0xFF00AAFF), 0.08,
              alignment: const Alignment(-0.9, 0.8)),
        ];
    }
  }

  static Widget _orb(
    double size,
    Color color,
    double opacity, {
    required AlignmentGeometry alignment,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared stagger mixin
// ─────────────────────────────────────────────────────────────────────────────

mixin _StaggerMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late AnimationController staggerCtrl;

  void initStagger({
    Duration duration = const Duration(milliseconds: 950),
  }) {
    staggerCtrl =
        AnimationController(vsync: this, duration: duration);
    staggerCtrl.forward();
  }

  @override
  void dispose() {
    staggerCtrl.dispose();
    super.dispose();
  }

  Animation<double> fade(double start, double end) => CurvedAnimation(
        parent: staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );

  Animation<Offset> rise(double start, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(
        CurvedAnimation(
          parent: staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );

  Animation<double> pop(double start, double end) => CurvedAnimation(
        parent: staggerCtrl,
        curve: Interval(start, end, curve: Curves.elasticOut),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable label styles
// ─────────────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Runtime',
          color: Colors.white.withOpacity(0.45),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      );
}

class _BigNumber extends StatelessWidget {
  final int value;
  final Color glowColor;
  final double size;
  const _BigNumber({
    required this.value,
    required this.glowColor,
    this.size = 100,
  });
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (_, val, __) => Text(
        '${val.round()}',
        style: TextStyle(
          fontFamily: 'Runtime',
          color: Colors.white,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1.0,
          letterSpacing: -size * 0.04,
          shadows: [
            Shadow(color: glowColor.withOpacity(0.6), blurRadius: 32),
            Shadow(color: glowColor.withOpacity(0.35), blurRadius: 72),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide 0 — Opener
// ─────────────────────────────────────────────────────────────────────────────

class _OpenerSlide extends StatefulWidget {
  final _SlideData data;
  const _OpenerSlide({required this.data});
  @override
  State<_OpenerSlide> createState() => _OpenerSlideState();
}

class _OpenerSlideState extends State<_OpenerSlide>
    with SingleTickerProviderStateMixin, _StaggerMixin {
  @override
  void initState() { super.initState(); initStagger(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          FadeTransition(
            opacity: fade(0.0, 0.4),
            child: ScaleTransition(
              scale: pop(0.0, 0.5),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.15), width: 1),
                ),
                child: const Icon(Icons.people_rounded,
                    size: 38, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Names tag
          FadeTransition(
            opacity: fade(0.2, 0.5),
            child: SlideTransition(
                position: rise(0.2, 0.5),
                child: _Tag(d.tag)),
          ),
          const SizedBox(height: 10),
          // Headline
          FadeTransition(
            opacity: fade(0.3, 0.65),
            child: SlideTransition(
              position: rise(0.3, 0.65),
              child: Text(
                d.headline,
                style: const TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white,
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -1.5,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Big number + label
          FadeTransition(
            opacity: fade(0.5, 0.8),
            child: SlideTransition(
              position: rise(0.5, 0.8),
              child: _BigNumber(
                value: d.primaryValue,
                glowColor: const Color(0xFF9B5FFF),
                size: 104,
              ),
            ),
          ),
          FadeTransition(
            opacity: fade(0.62, 0.9),
            child: SlideTransition(
              position: rise(0.62, 0.9),
              child: Text(
                d.detail,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide 1 — Connection count
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionSlide extends StatefulWidget {
  final _SlideData data;
  const _ConnectionSlide({required this.data});
  @override
  State<_ConnectionSlide> createState() => _ConnectionSlideState();
}

class _ConnectionSlideState extends State<_ConnectionSlide>
    with SingleTickerProviderStateMixin, _StaggerMixin {
  @override
  void initState() { super.initState(); initStagger(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    const green = Color(0xFF3DFFA0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: fade(0.0, 0.4),
            child: ScaleTransition(
              scale: pop(0.0, 0.5),
              child: const Icon(Icons.favorite_rounded,
                  color: green, size: 60),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: fade(0.2, 0.5),
            child: SlideTransition(
                position: rise(0.2, 0.5), child: _Tag(d.tag)),
          ),
          const SizedBox(height: 10),
          FadeTransition(
            opacity: fade(0.3, 0.65),
            child: SlideTransition(
              position: rise(0.3, 0.65),
              child: Text(
                d.headline,
                style: const TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const Spacer(),
          FadeTransition(
            opacity: fade(0.5, 0.8),
            child: _BigNumber(
              value: d.primaryValue,
              glowColor: green,
              size: 112,
            ),
          ),
          const SizedBox(height: 6),
          FadeTransition(
            opacity: fade(0.62, 0.9),
            child: SlideTransition(
              position: rise(0.62, 0.9),
              child: Text(
                d.detail,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide 2 — Match rate  (big glowing %, no bar)
// ─────────────────────────────────────────────────────────────────────────────

class _MatchRateSlide extends StatefulWidget {
  final _SlideData data;
  const _MatchRateSlide({required this.data});
  @override
  State<_MatchRateSlide> createState() => _MatchRateSlideState();
}

class _MatchRateSlideState extends State<_MatchRateSlide>
    with SingleTickerProviderStateMixin, _StaggerMixin {
  @override
  void initState() { super.initState(); initStagger(duration: const Duration(milliseconds: 1100)); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    const blue = Color(0xFF5EA8FF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: fade(0.0, 0.4),
            child: SlideTransition(
              position: rise(0.0, 0.4),
              child: _Tag(d.tag),
            ),
          ),
          const Spacer(),
          // Giant percentage — counted up with glow
          FadeTransition(
            opacity: fade(0.15, 0.55),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: d.primaryValue.toDouble()),
              duration: const Duration(milliseconds: 1050),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${val.round()}',
                    style: const TextStyle(
                      fontFamily: 'Runtime',
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -5,
                      shadows: [
                        Shadow(
                            color: Color(0x995EA8FF), blurRadius: 40),
                        Shadow(
                            color: Color(0x555EA8FF), blurRadius: 80),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '%',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        shadows: const [
                          Shadow(color: Color(0x775EA8FF), blurRadius: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FadeTransition(
            opacity: fade(0.55, 0.85),
            child: SlideTransition(
              position: rise(0.55, 0.85),
              child: Text(
                d.detail,
                style: const TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide 3 — Top category  (icon, no emojis)
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySlide extends StatefulWidget {
  final _SlideData data;
  const _CategorySlide({required this.data});
  @override
  State<_CategorySlide> createState() => _CategorySlideState();
}

class _CategorySlideState extends State<_CategorySlide>
    with SingleTickerProviderStateMixin, _StaggerMixin {
  @override
  void initState() { super.initState(); initStagger(); }

  static IconData _icon(String cat) {
    switch (cat) {
      case 'Love and Intimacy':             return Icons.favorite_rounded;
      case 'Spirituality':                  return Icons.brightness_3_rounded;
      case 'Society':                       return Icons.public_rounded;
      case 'Interactions and Relationships':return Icons.people_rounded;
      case 'Personal Development':          return Icons.trending_up_rounded;
      default:                              return Icons.chat_bubble_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    const amber = Color(0xFFFFB347);

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category icon in a glowing circle
          FadeTransition(
            opacity: fade(0.0, 0.4),
            child: ScaleTransition(
              scale: pop(0.0, 0.5),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      amber.withOpacity(0.25),
                      amber.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                      color: amber.withOpacity(0.35), width: 1),
                ),
                child: Icon(_icon(d.headline),
                    size: 36, color: amber),
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: fade(0.2, 0.5),
            child: SlideTransition(
                position: rise(0.2, 0.5), child: _Tag(d.tag)),
          ),
          const SizedBox(height: 10),
          FadeTransition(
            opacity: fade(0.32, 0.68),
            child: SlideTransition(
              position: rise(0.32, 0.68),
              child: Text(
                d.headline,
                style: const TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(color: Color(0x88FFB347), blurRadius: 24),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          FadeTransition(
            opacity: fade(0.6, 0.9),
            child: SlideTransition(
              position: rise(0.6, 0.9),
              child: Text(
                d.detail,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide 4 — Differed
// ─────────────────────────────────────────────────────────────────────────────

class _DifferedSlide extends StatefulWidget {
  final _SlideData data;
  const _DifferedSlide({required this.data});
  @override
  State<_DifferedSlide> createState() => _DifferedSlideState();
}

class _DifferedSlideState extends State<_DifferedSlide>
    with SingleTickerProviderStateMixin, _StaggerMixin {
  @override
  void initState() { super.initState(); initStagger(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    const rose = Color(0xFFFF6B9D);

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: fade(0.0, 0.4),
            child: ScaleTransition(
              scale: pop(0.0, 0.5),
              child: const Icon(Icons.compare_arrows_rounded,
                  color: rose, size: 60),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: fade(0.2, 0.5),
            child: SlideTransition(
                position: rise(0.2, 0.5), child: _Tag(d.tag)),
          ),
          const SizedBox(height: 10),
          FadeTransition(
            opacity: fade(0.3, 0.65),
            child: SlideTransition(
              position: rise(0.3, 0.65),
              child: Text(
                d.headline,
                style: const TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const Spacer(),
          FadeTransition(
            opacity: fade(0.55, 0.85),
            child: SlideTransition(
              position: rise(0.55, 0.85),
              child: Text(
                d.detail,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide last — Outro
// ─────────────────────────────────────────────────────────────────────────────

class _OutroSlide extends StatefulWidget {
  final _SlideData data;
  final VoidCallback onFinish;
  const _OutroSlide({required this.data, required this.onFinish});
  @override
  State<_OutroSlide> createState() => _OutroSlideState();
}

class _OutroSlideState extends State<_OutroSlide>
    with SingleTickerProviderStateMixin, _StaggerMixin {
  @override
  void initState() { super.initState(); initStagger(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: fade(0.0, 0.4),
            child: ScaleTransition(
              scale: pop(0.0, 0.5),
              child: const _SpinningSparkle(),
            ),
          ),
          const Spacer(),
          FadeTransition(
            opacity: fade(0.25, 0.65),
            child: SlideTransition(
              position: rise(0.25, 0.65),
              child: Text(
                widget.data.headline,
                style: const TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1.2,
                  shadows: [
                    Shadow(color: Color(0x667B4FFF), blurRadius: 40),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          FadeTransition(
            opacity: fade(0.55, 0.85),
            child: SlideTransition(
              position: rise(0.55, 0.85),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF08001C),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'See Full Results',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Spinning sparkle icon
// ─────────────────────────────────────────────────────────────────────────────

class _SpinningSparkle extends StatefulWidget {
  const _SpinningSparkle();
  @override
  State<_SpinningSparkle> createState() => _SpinningSparkleState();
}

class _SpinningSparkleState extends State<_SpinningSparkle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withOpacity(0.15),
              Colors.transparent,
            ]),
            border:
                Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 38, color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int count;
  final int current;
  const _ProgressBar({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final active = i == current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            margin: EdgeInsets.only(right: i < count - 1 ? 4 : 0),
            height: 2.5,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.85)
                  : Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tap hint
// ─────────────────────────────────────────────────────────────────────────────

class _TapHint extends StatefulWidget {
  const _TapHint();
  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim =
        Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    ));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const Text(
        'Tap to continue',
        style: TextStyle(
          fontFamily: 'Runtime',
          color: Colors.white,
          fontSize: 11,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
