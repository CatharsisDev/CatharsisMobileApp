import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The Circle mode logo — a coloured disc with "Circle" orbiting around the
/// centre. Drop it anywhere you need the brand mark at any size.
///
/// [size]      — overall diameter of the widget.
/// [bgColor]   — fill colour of the disc.
/// [textColor] — colour of the orbiting text (uses a contrasting halo).
class CircleModeIcon extends StatefulWidget {
  final double size;
  final Color bgColor;
  final Color textColor;

  const CircleModeIcon({
    super.key,
    required this.size,
    required this.bgColor,
    required this.textColor,
  });

  @override
  State<CircleModeIcon> createState() => _CircleModeIconState();
}

class _CircleModeIconState extends State<CircleModeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Coloured background disc
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.bgColor,
            ),
          ),
          // Orbiting "Circle" text
          AnimatedBuilder(
            animation: _spin,
            builder: (_, __) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: CircleOrbitPainter(
                text: 'Circle',
                fontSize: widget.size * 0.19,
                textColor: widget.textColor,
                angleOffset: _spin.value * 2 * math.pi,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Painter shared by CircleModeIcon and the home-screen _CircleButton.
// ──────────────────────────────────────────────────────────────────────────────

class CircleOrbitPainter extends CustomPainter {
  final String text;
  final double fontSize;
  final Color textColor;
  final String fontFamily;
  final double angleOffset;

  const CircleOrbitPainter({
    required this.text,
    required this.fontSize,
    required this.textColor,
    this.fontFamily = 'Runtime',
    this.angleOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.68;
    final approxCharWidth = fontSize * 0.62;
    final charAngleStep = approxCharWidth / radius;

    // Contrasting halo: white behind dark text, dark behind light text
    final haloColor = textColor.computeLuminance() > 0.4
        ? Colors.black.withOpacity(0.55)
        : Colors.white.withOpacity(0.55);

    for (int i = 0; i < text.length; i++) {
      final angle = -math.pi / 2 + angleOffset + i * charAngleStep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            color: textColor,
            fontWeight: FontWeight.w900,
            height: 1.0,
            shadows: [
              Shadow(
                color: haloColor,
                blurRadius: 7,
                offset: Offset.zero,
              ),
              Shadow(
                color: haloColor.withOpacity(0.3),
                blurRadius: 16,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CircleOrbitPainter old) =>
      old.angleOffset != angleOffset ||
      old.textColor != textColor ||
      old.text != text;
}
