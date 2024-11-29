import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';

class CountdownTimerWidget extends StatelessWidget {
  final DateTime? resetTime;
  final VoidCallback? onTimerEnd;

  const CountdownTimerWidget({
    Key? key,
    required this.resetTime,
    this.onTimerEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (resetTime == null) {
      return const Text(
        "No timer available",
        style: TextStyle(
          fontSize: 16.0,
          color: Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final int endTime = resetTime!.millisecondsSinceEpoch;

    return CountdownTimer(
      endTime: endTime,
      widgetBuilder: (_, remainingTime) {
        if (remainingTime == null) {
          return const Text(
            "Time is up!",
            style: TextStyle(
              fontSize: 18.0,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          );
        }
        return Text(
          "${remainingTime.hours ?? 0}h ${remainingTime.min ?? 0}m ${remainingTime.sec ?? 0}s",
          style: const TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        );
      },
      onEnd: () {
        print("Timer ended.");
        if (onTimerEnd != null) {
          onTimerEnd!();
        }
      },
    );
  }
}