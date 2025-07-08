import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class FlutterFlowSwipeableStack extends StatefulWidget {
  const FlutterFlowSwipeableStack({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    required this.controller,
    required this.onRightSwipe,
    required this.onLeftSwipe,
    required this.loop,
    required this.cardDisplayCount,
    required this.scale,
    this.maxAngle,
    this.threshold,
    this.cardPadding,
    this.backCardOffset,
  });

  final Widget Function(BuildContext, int) itemBuilder;
  final CardSwiperController controller;
  final int itemCount;
  final Function(int) onRightSwipe;
  final Function(int) onLeftSwipe;
  final bool loop;
  final int cardDisplayCount;
  final double scale;
  final double? maxAngle;
  final double? threshold;
  final EdgeInsetsGeometry? cardPadding;
  final Offset? backCardOffset;

  @override
  _FFSwipeableStackState createState() => _FFSwipeableStackState();
}

class _FFSwipeableStackState extends State<FlutterFlowSwipeableStack> {
  @override
  Widget build(BuildContext context) {
    return CardSwiper(
      controller: widget.controller,
      onSwipe: (previousIndex, currentIndex, direction) {
        if (direction == CardSwiperDirection.left) {
          widget.onLeftSwipe(previousIndex);
        } else if (direction == CardSwiperDirection.right) {
          widget.onRightSwipe(previousIndex);
        }
        return true;
      },
      cardsCount: widget.itemCount,
      cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
        return widget.itemBuilder(context, index);
      },
      isLoop: widget.loop,
      maxAngle: widget.maxAngle ?? 30,
      threshold:
          widget.threshold != null ? (100 * widget.threshold!).round() : 50,
      scale: widget.scale,
      padding: widget.cardPadding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      backCardOffset: widget.backCardOffset ?? const Offset(0, 40),
      numberOfCardsDisplayed: widget.cardDisplayCount < widget.itemCount
          ? widget.cardDisplayCount
          : widget.itemCount,
    );
  }
}
