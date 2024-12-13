import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/theme_provider.dart';

class SwipeLimitPopup extends ConsumerWidget {
  final DateTime? resetTime;
  final VoidCallback onDismiss;
  final VoidCallback onPurchase;
  final VoidCallback onTimerEnd; // New callback for handling timer end

  const SwipeLimitPopup({
    Key? key,
    required this.resetTime,
    required this.onDismiss,
    required this.onPurchase,
    required this.onTimerEnd, // Pass the onTimerEnd callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double borderRadiusValue = 15;

    return Stack(
      children: [
        // Dimmed background
        Positioned.fill(
          child: GestureDetector(
            onTap: () {}, // Disable interactions outside the popup
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 400,
            height: 550,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: Border.all(
                color: const Color.fromARGB(255, 162, 156, 154),
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: borderRadiusValue,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
 ref.watch(themeProvider).themeName == 'dark'
   ? 'assets/images/dark_mode_card_background.png'
   : ref.watch(themeProvider).themeName == 'light'
     ? 'assets/images/light_mode_card_background.png'  
     : 'assets/images/catharsis_signature_theme_card_background.png',
 fit: BoxFit.cover,
 width: 405,
 height: 555,
),
                ),
                // Close button
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(
                      Icons.close,
                      color: Colors.grey,
                      size: 30,
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Swipe Limit Reached',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.raleway(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'You have used up your swipes for now. Please wait for the timer to reset or purchase additional swipes.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.raleway(
                          fontSize: 18,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (resetTime != null)
                        CountdownTimer(
                          endTime: resetTime!.millisecondsSinceEpoch,
                          textStyle: GoogleFonts.raleway(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          onEnd: onTimerEnd, // Call onTimerEnd when the timer ends
                        )
                      else
                        Text(
                          'No timer available',
                          style: GoogleFonts.raleway(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: onPurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(227, 95, 66, 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 40,
                          ),
                        ),
                        child: Text(
                          'Purchase Swipes',
                          style: GoogleFonts.raleway(
                            fontSize: 20,
                            color: Colors.white,
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
      ],
    );
  }
}