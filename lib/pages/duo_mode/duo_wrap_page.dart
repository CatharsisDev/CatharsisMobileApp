import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/duo_session.dart';
import '../../provider/duo_provider.dart';
import '../../components/circle_mode_icon.dart';

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

enum _SlideType { opener, connection, matchRate, smartFact, topCategory, differed, outro }

/// A single general-knowledge fact shown on the smart fact slide.
class _Fact {
  final String headline; // short punchy label (big text)
  final String body;     // full sentence explaining the fact
  const _Fact({required this.headline, required this.body});
}

class _SlideData {
  final _SlideType type;
  final int primaryValue;
  final String headline;
  final String detail;     // secondary line
  final String tag;        // small top label
  final String subDetail;  // optional third line (legacy)
  final String factHeadline; // inline fact keyword (shown on match-rate slide)
  final String factBody;     // inline fact sentence

  const _SlideData({
    required this.type,
    required this.primaryValue,
    required this.headline,
    this.detail = '',
    this.tag = '',
    this.subDetail = '',
    this.factHeadline = '',
    this.factBody = '',
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
  bool _forward = true; // tracks direction for slide animation
  late List<_SlideData> _slides;

  // Background cross-fade controller
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  // Share capture
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _isCapturing = false;

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

  Future<void> _captureAndShare() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      // Let any in-progress frames fully paint before capturing.
      await Future.delayed(const Duration(milliseconds: 80));

      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[DuoWrap] boundary is null — cannot capture');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/catharsis_recap_slide_$_page.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      // Compute the share button's screen rect so iOS can anchor the popover.
      final buttonBox = _shareButtonKey.currentContext?.findRenderObject()
          as RenderBox?;
      final Rect? origin = buttonBox != null
          ? buttonBox.localToGlobal(Offset.zero) & buttonBox.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e, st) {
      debugPrint('[DuoWrap] share error: $e\n$st');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  static List<_SlideData> _buildSlides(DuoSession session) {
    final total    = session.cards.length;
    final matched  = session.matchedCards.length;
    final differed = session.splitCards.length;
    final pct      = total > 0 ? ((matched / total) * 100).round() : 0;
    final partner  = session.guestName ?? 'Partner';
    final topCat   = _topCategory(session.matchedCards);
    // Three distinct facts spread across slides (offsets are coprime with 22)
    final fact0 = _pickFact(session, offset: 0);   // connection slide
    final fact1 = _pickFact(session, offset: 7);   // match rate slide
    final fact2 = _pickFact(session, offset: 14);  // outro slide

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
        factHeadline: fact0.headline,
        factBody: fact0.body,
      ),
      _SlideData(
        type: _SlideType.matchRate,
        primaryValue: pct,
        tag: 'Match rate',
        headline: '$pct%',
        detail: _rateCaption(pct),
        factHeadline: fact1.headline,
        factBody: fact1.body,
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
      _SlideData(
        type: _SlideType.outro,
        primaryValue: 0,
        headline: 'Every question\nbrings you\ncloser.',
        factHeadline: fact2.headline,
        factBody: fact2.body,
      ),
    ];
  }

  /// Picks a general-knowledge fact about love/relationships, deterministically
  /// seeded from the session code. [offset] lets three different facts be
  /// selected for the same session (offsets 0, 7, 14 are coprime with 22,
  /// so they always yield 3 distinct entries).
  static _Fact _pickFact(DuoSession session, {int offset = 0}) {
    final seed = session.sessionCode.codeUnits.fold(0, (a, b) => a + b);
    return _relationshipFacts[(seed + offset) % _relationshipFacts.length];
  }

  static const _relationshipFacts = [
    _Fact(
      headline: '4 minutes',
      body: 'Sustained eye contact for just 4 minutes can produce feelings of deep mutual attraction — even between strangers.',
    ),
    _Fact(
      headline: '200 hours',
      body: 'Research shows it takes around 200 hours of quality time together for two people to develop a close friendship.',
    ),
    _Fact(
      headline: 'oxytocin',
      body: 'A 20-second hug floods your brain with oxytocin — the bonding hormone — lowering stress and deepening trust between people.',
    ),
    _Fact(
      headline: '7 times',
      body: 'On average, a person falls in love 7 times before finding a lasting partnership.',
    ),
    _Fact(
      headline: '90 seconds',
      body: 'Scientists believe initial romantic attraction is determined within 90 seconds, mostly through body language and tone of voice.',
    ),
    _Fact(
      headline: 'mirror neurons',
      body: 'When you watch someone you care about feel pain, your brain activates the same regions as if you felt it yourself — empathy is neurological.',
    ),
    _Fact(
      headline: '36 questions',
      body: 'Psychologist Arthur Aron found that answering 36 specific questions — designed to build mutual vulnerability — can make two strangers feel deeply connected in under an hour.',
    ),
    _Fact(
      headline: 'same laugh',
      body: 'Couples who genuinely laugh together report significantly higher satisfaction and are more likely to stay together long-term.',
    ),
    _Fact(
      headline: 'left side',
      body: 'People tend to show more emotion on the left side of their face. Partners often unconsciously position themselves to see each other\'s emotional side during deep conversations.',
    ),
    _Fact(
      headline: '3 components',
      body: 'Psychologist Robert Sternberg\'s Triangle Theory says all forms of love are built from three elements: intimacy, passion, and commitment.',
    ),
    _Fact(
      headline: 'hand holding',
      body: 'Holding a romantic partner\'s hand during a stressful moment measurably reduces pain perception and lowers blood pressure.',
    ),
    _Fact(
      headline: 'scent memory',
      body: 'Of all the senses, smell is most directly linked to memory and emotion. The scent of a loved one can instantly reduce anxiety.',
    ),
    _Fact(
      headline: '5:1 ratio',
      body: 'Relationship researcher John Gottman found that couples who thrive have at least 5 positive interactions for every 1 negative one.',
    ),
    _Fact(
      headline: 'brain in love',
      body: 'Brain scans show that romantic love activates the same dopamine pathways as addictive substances — being in love is neurologically similar to a natural high.',
    ),
    _Fact(
      headline: 'butterfly effect',
      body: 'Those butterflies in your stomach are real — they\'re caused by adrenaline released when you see someone you\'re attracted to.',
    ),
    _Fact(
      headline: '12 types',
      body: 'Ancient Greeks identified 12 distinct types of love — from eros (romantic passion) to pragma (enduring love) to philautia (self-love).',
    ),
    _Fact(
      headline: 'look alike',
      body: 'Long-term couples gradually start to look more similar to each other — scientists believe this happens because of shared emotions and mirrored facial expressions over time.',
    ),
    _Fact(
      headline: 'vulnerability',
      body: 'Research by Brené Brown shows that the willingness to be vulnerable is the single greatest predictor of closeness and connection between two people.',
    ),
    _Fact(
      headline: '2 years',
      body: 'The intense early stage of romantic love — driven by norepinephrine and dopamine — typically lasts 12 to 24 months before transitioning into deeper attachment.',
    ),
    _Fact(
      headline: 'active listening',
      body: 'Studies show that people who feel genuinely heard by their partner report 40% higher relationship satisfaction than those who don\'t.',
    ),
    _Fact(
      headline: 'slow down',
      body: 'Couples who take longer to move in together tend to report stronger long-term satisfaction — slowing down builds a more solid foundation.',
    ),
    _Fact(
      headline: 'touch matters',
      body: 'Non-sexual physical touch — like a pat on the back or a squeeze of the arm — plays a crucial role in maintaining emotional connection between partners.',
    ),
  ];

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
      _forward = true;
      _prevPage = _page;
      _page++;
    });
    _bgCtrl.forward(from: 0);
  }

  void _goBack() {
    if (_page <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _forward = false;
      _prevPage = _page;
      _page--;
    });
    _bgCtrl.forward(from: 0);
  }

  // ── Background colour pairs per slide type ──────────────────────────────
  static const _bgColors = <_SlideType, List<Color>>{
    _SlideType.opener:      [Color(0xFF07001A), Color(0xFF13003A)],
    _SlideType.connection:  [Color(0xFF001210), Color(0xFF002A1C)],
    _SlideType.matchRate:   [Color(0xFF000A1E), Color(0xFF001040)],
    _SlideType.smartFact:   [Color(0xFF001A18), Color(0xFF00312C)],
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── RepaintBoundary at stable level (outside AnimatedBuilder) ──────
          // This ensures GlobalKey.currentContext is always valid when sharing.
          RepaintBoundary(
            key: _repaintKey,
            child: GestureDetector(
              onTap: slide.type == _SlideType.outro ? null : _advance,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v > 200) {
                  _goBack();
                } else if (v < -200 && slide.type != _SlideType.outro) {
                  _advance();
                }
              },
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
                          // ── Decorative orb layer ─────────────────────────
                          _OrbLayer(type: slide.type),

                          // ── Progress bar ─────────────────────────────────
                          Positioned(
                            top: 16, left: 24, right: 80,
                            child: _ProgressBar(
                              count: _slides.length,
                              current: _page,
                            ),
                          ),

                          // ── Slide content (cross-fades on page change) ───
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: _forward
                                        ? const Offset(0.06, 0)
                                        : const Offset(-0.06, 0),
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

                          // ── Catharsis logo watermark (baked into share) ──
                          Positioned(
                            bottom: 6, left: 0, right: 0,
                            child: Center(
                              child: Image.asset(
                                'assets/images/catharsis_word_only.png',
                                height: 14,
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                          ),

                          // ── Tap hint ─────────────────────────────────────
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
            ),
          ),

          // ── Share button (outside RepaintBoundary — not in screenshot) ─────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: _WrapShareButton(
                  key: _shareButtonKey,
                  isCapturing: _isCapturing,
                  onTap: _captureAndShare,
                ),
              ),
            ),
          ),

          // ── Back button (top left, outside screenshot boundary) ──────────
          if (_page > 0)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: GestureDetector(
                    onTap: _goBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white54, size: 22),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(_SlideData d) {
    switch (d.type) {
      case _SlideType.opener:      return _OpenerSlide(data: d);
      case _SlideType.connection:  return _ConnectionSlide(data: d);
      case _SlideType.matchRate:   return _MatchRateSlide(data: d);
      case _SlideType.smartFact:   return _SmartFactSlide(data: d);
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
      case _SlideType.smartFact:
        return [
          _orb(520, const Color(0xFF00FFCC), 0.10,
              alignment: const Alignment(0.8, -0.9)),
          _orb(400, const Color(0xFF00CCA3), 0.12,
              alignment: const Alignment(-1.1, 0.5)),
          _orb(260, const Color(0xFF00FFE0), 0.07,
              alignment: const Alignment(0.1, 0.2)),
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
              child: const CircleModeIcon(
                size: 72,
                bgColor: Colors.white12,
                textColor: Colors.white,
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
          if (d.factHeadline.isNotEmpty) ...[
            const SizedBox(height: 28),
            FadeTransition(
              opacity: fade(0.72, 0.95),
              child: SlideTransition(
                position: rise(0.72, 0.95),
                child: _InlineFactCard(
                    headline: d.factHeadline, body: d.factBody),
              ),
            ),
            const SizedBox(height: 20),
          ],
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

          // ── Inline smart fact ──────────────────────────────────────────
          if (d.factHeadline.isNotEmpty) ...[
            const SizedBox(height: 36),
            FadeTransition(
              opacity: fade(0.70, 0.95),
              child: SlideTransition(
                position: rise(0.70, 0.95),
                child: _InlineFactCard(
                    headline: d.factHeadline, body: d.factBody),
              ),
            ),
            const SizedBox(height: 24),
          ] else
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
      // Solo mode categories
      case 'Love and Intimacy':              return Icons.favorite_rounded;
      case 'Spirituality':                   return Icons.brightness_3_rounded;
      case 'Society':                        return Icons.public_rounded;
      case 'Interactions and Relationships': return Icons.people_rounded;
      case 'Personal Development':           return Icons.trending_up_rounded;
      // Duo mode categories
      case 'Love & Relationships':           return Icons.favorite_rounded;
      case 'Values & Beliefs':               return Icons.balance_rounded;
      case 'Family & Future':                return Icons.family_restroom_rounded;
      case 'Lifestyle & Habits':             return Icons.self_improvement_rounded;
      case 'Communication & Conflict':       return Icons.chat_bubble_rounded;
      default:                               return Icons.chat_bubble_rounded;
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
//  Shared inline fact card (rendered inside existing slides)
// ─────────────────────────────────────────────────────────────────────────────

class _InlineFactCard extends StatelessWidget {
  final String headline;
  final String body;
  const _InlineFactCard({required this.headline, required this.body});

  /// Capitalises the first character of [s], leaving the rest unchanged.
  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00FFCC);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: teal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: teal.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded,
                  size: 11, color: teal.withOpacity(0.75)),
              const SizedBox(width: 5),
              Text(
                'DID YOU KNOW',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: teal.withOpacity(0.75),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _cap(headline),
            style: const TextStyle(
              fontFamily: 'Runtime',
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.4,
              shadows: [Shadow(color: Color(0x4400FFCC), blurRadius: 20)],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _cap(body),
            style: TextStyle(
              fontFamily: 'Runtime',
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Smart fact slide
// ─────────────────────────────────────────────────────────────────────────────

class _SmartFactSlide extends StatefulWidget {
  final _SlideData data;
  const _SmartFactSlide({required this.data});
  @override
  State<_SmartFactSlide> createState() => _SmartFactSlideState();
}

class _SmartFactSlideState extends State<_SmartFactSlide>
    with SingleTickerProviderStateMixin, _StaggerMixin {
  @override
  void initState() {
    super.initState();
    initStagger(duration: const Duration(milliseconds: 1000));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    const teal = Color(0xFF00FFCC);

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Did you know" badge
          FadeTransition(
            opacity: fade(0.0, 0.35),
            child: SlideTransition(
              position: rise(0.0, 0.35),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: teal.withOpacity(0.30), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_rounded,
                        size: 12, color: teal.withOpacity(0.85)),
                    const SizedBox(width: 6),
                    Text(
                      d.tag.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: teal.withOpacity(0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Main headline — the fact itself
          FadeTransition(
            opacity: fade(0.2, 0.6),
            child: SlideTransition(
              position: rise(0.2, 0.6),
              child: Text(
                d.headline,
                style: const TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1.0,
                  shadows: [
                    Shadow(color: Color(0x6600FFCC), blurRadius: 32),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Divider line
          FadeTransition(
            opacity: fade(0.5, 0.75),
            child: Container(
              height: 1,
              width: 48,
              color: teal.withOpacity(0.30),
              margin: const EdgeInsets.only(bottom: 18),
            ),
          ),

          // Detail
          FadeTransition(
            opacity: fade(0.55, 0.82),
            child: SlideTransition(
              position: rise(0.55, 0.82),
              child: Text(
                d.detail,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),

          if (d.subDetail.isNotEmpty) ...[
            const SizedBox(height: 10),
            FadeTransition(
              opacity: fade(0.68, 0.92),
              child: SlideTransition(
                position: rise(0.68, 0.92),
                child: Text(
                  d.subDetail,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: teal.withOpacity(0.70),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
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
          if (widget.data.factHeadline.isNotEmpty) ...[
            const SizedBox(height: 32),
            FadeTransition(
              opacity: fade(0.45, 0.78),
              child: SlideTransition(
                position: rise(0.45, 0.78),
                child: _InlineFactCard(
                    headline: widget.data.factHeadline,
                    body: widget.data.factBody),
              ),
            ),
            const SizedBox(height: 32),
          ] else
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
//  Share button (overlaid outside the RepaintBoundary)
// ─────────────────────────────────────────────────────────────────────────────

class _WrapShareButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;
  const _WrapShareButton({
    super.key,
    required this.isCapturing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
        ),
        child: isCapturing
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white),
              )
            : const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
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
