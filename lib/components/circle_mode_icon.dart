import 'package:flutter/material.dart';

/// The Circle mode logo — displays the circle_icon asset at the requested size.
///
/// [size]      — overall diameter of the widget.
/// [bgColor]   — fill colour of the circular background disc.
/// [textColor] — tint colour applied to the icon image.
class CircleModeIcon extends StatelessWidget {
  final double size;
  final Color bgColor;
  final Color textColor;

  const CircleModeIcon({
    super.key,
    required this.size,
    this.bgColor = Colors.transparent,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.24),
        child: Image.asset(
          'assets/images/circle_icon.png',
          fit: BoxFit.contain,
          color: textColor,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}
