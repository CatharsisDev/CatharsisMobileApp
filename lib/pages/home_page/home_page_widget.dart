import 'dart:math';
import 'package:catharsis_cards/provider/auth_provider.dart';
import 'package:catharsis_cards/provider/theme_provider.dart';
import 'package:catharsis_cards/question_categories.dart';
import '../../services/user_beahvior_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/components/gamecard_widget.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/pop_up_provider.dart';
import '../../provider/tutorial_state_provider.dart';
import '/components/swipe_limit_popup.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme_settings/theme_settings_page.dart';
import 'package:catharsis_cards/questions_model.dart';

class HomePageWidget extends ConsumerStatefulWidget {
  const HomePageWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends ConsumerState<HomePageWidget>
    with TickerProviderStateMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late CardSwiperController _cardController;
  late AnimationController _handController;
  late Animation<Offset> _swipeAnimation;

  @override
  void initState() {
    super.initState();
    _cardController = CardSwiperController();

    _handController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _swipeAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0.0),
      end: const Offset(0.1, 0.0),
    ).animate(CurvedAnimation(
      parent: _handController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _cardController.dispose();
    _handController.dispose();
    super.dispose();
  }

  void _showExtraPackagePopUp(BuildContext context, DateTime? resetTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SwipeLimitPopup(
        resetTime: resetTime,
        onDismiss: () {
          Navigator.of(context).pop();
          ref.read(popUpProvider.notifier).hidePopUp();
        },
        onPurchase: () {
          // Add purchase logic
        },
        onTimerEnd: () {
          Navigator.of(context).pop();
          ref.read(popUpProvider.notifier).hidePopUp();
        },
      ),
    );
  }

  void _openPreferences() {
    final notifier = ref.read(cardStateProvider.notifier);
    final current = ref.read(cardStateProvider).selectedCategories;
    
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final categories = QuestionCategories.getAllCategories();
        final tempSelected = Set<String>.from(current);

        return StatefulBuilder(
          builder: (_, setState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Filter Categories',
                      style: GoogleFonts.raleway(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...categories.map((cat) => CheckboxListTile(
                    title: Text(cat),
                    value: tempSelected.contains(cat),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          tempSelected.add(cat);
                        } else {
                          tempSelected.remove(cat);
                        }
                      });
                    },
                  )),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() => tempSelected.clear()),
                          child: const Text('Clear All'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            notifier.updateSelectedCategories(tempSelected);
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(cardStateProvider);
    final notifier = ref.read(cardStateProvider.notifier);
    final showTutorial = ref.watch(tutorialProvider);
    final tutorialNotifier = ref.read(tutorialProvider.notifier);

    // Check if current question is liked
    final isCurrentQuestionLiked = cardState.currentQuestion != null &&
        cardState.likedQuestions.any((q) =>
            q.text == cardState.currentQuestion!.text &&
            q.category == cardState.currentQuestion!.category);

    // Listen for popup trigger
    ref.listen<bool>(popUpProvider, (_, next) {
      if (next) {
        _showExtraPackagePopUp(context, cardState.swipeResetTime);
      }
    });

    return Stack(
      children: [
        GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: ref.watch(themeProvider).themeName == 'dark'
                ? Theme.of(context).scaffoldBackgroundColor
                : ref.watch(themeProvider).themeName == 'light'
                    ? const Color.fromARGB(235, 201, 197, 197)
                    : const Color.fromRGBO(208, 164, 180, 0.95),
            body: SafeArea(
              child: Stack(
                children: [
                  // Background gradient
                  Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: MediaQuery.sizeOf(context).height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: ref.watch(themeProvider).themeName == 'dark'
                            ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
                            : ref.watch(themeProvider).themeName == 'light'
                                ? [
                                    const Color.fromARGB(235, 201, 197, 197),
                                    const Color.fromARGB(255, 255, 255, 255)
                                  ]
                                : [
                                    const Color.fromARGB(235, 208, 164, 180),
                                    const Color.fromARGB(255, 140, 198, 255)
                                  ],
                        stops: const [0.0, 1.0],
                        begin: const AlignmentDirectional(0.6, -0.34),
                        end: const AlignmentDirectional(-1.0, 0.34),
                      ),
                    ),
                  ),
                  
                  // Card Stack
                  if (cardState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Align(
                      alignment: const AlignmentDirectional(0.0, 0.0),
                      child: Container(
                        width: MediaQuery.sizeOf(context).width * 4.0,
                        height: 485.0,
                        child: Stack(
                          alignment: const AlignmentDirectional(0.0, 0.0),
                          children: [
                            FlutterFlowSwipeableStack(
                              controller: _cardController,
                              itemCount: cardState.activeQuestions.isEmpty 
                                  ? 1 
                                  : cardState.activeQuestions.length,
                              itemBuilder: (context, index) {
                                final questions = cardState.activeQuestions;
                                if (questions.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No questions available',
                                      style: GoogleFonts.raleway(
                                        color: Colors.white,
                                        fontSize: 20.0,
                                      ),
                                    ),
                                  );
                                }
                                
                                final normalizedIndex = index % questions.length;
                                final question = questions[normalizedIndex];
                                
                                return Stack(
                                  children: [
                                    Align(
                                      alignment: const AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: GamecardWidget(),
                                      ),
                                    ),
                                    Align(
                                      alignment: const AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        width: 400.0,
                                        height: 400.0,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Align(
                                              alignment: const AlignmentDirectional(0.0, 0.0),
                                              child: Padding(
                                                padding: const EdgeInsetsDirectional.fromSTEB(
                                                    20.0, 20.0, 20.0, 60.0),
                                                child: Text(
                                                  question.text,
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.raleway(
                                                    color: Colors.white,
                                                    fontSize: 28.0,
                                                    letterSpacing: 0.2,
                                                    shadows: [
                                                      Shadow(
                                                        color: FlutterFlowTheme.of(context)
                                                            .secondaryText,
                                                        offset: const Offset(2.0, 2.0),
                                                        blurRadius: 2.0,
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 20,
                                              child: Text(
                                                question.category,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.raleway(
                                                  color: Colors.white,
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.0,
                                                  shadows: [
                                                    Shadow(
                                                      color: FlutterFlowTheme.of(context)
                                                          .secondaryText,
                                                      offset: const Offset(2.0, 2.0),
                                                      blurRadius: 2.0,
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              onLeftSwipe: (index) {
                                // Pass direction and velocity to handleCardSwiped
                                notifier.handleCardSwiped(
                                  index, 
                                  direction: 'left', 
                                  velocity: 0.5
                                );
                              },
                              onRightSwipe: (index) {
                                // Right swipe: like then advance
                                final questions = cardState.activeQuestions;
                                if (questions.isNotEmpty) {
                                  final q = questions[index % questions.length];
                                  notifier.toggleLiked(q);
                                }
                                notifier.handleCardSwiped(
                                  index,
                                  direction: 'right',
                                  velocity: 0.5
                                );
                              },
                              loop: true,
                              cardDisplayCount: 4,
                              scale: 0.9,
                              threshold: 0.7,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Heart and Share Icons below card stack
                  Positioned(
                    bottom: 50,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Heart Icon
                        IconButton(
                          icon: FaIcon(
                            isCurrentQuestionLiked
                                ? FontAwesomeIcons.solidBookmark
                                : FontAwesomeIcons.bookmark,
                            color: isCurrentQuestionLiked 
                                ? Colors.red
                                : Colors.white,
                            size: 30.0,
                          ),
                          onPressed: () {
                            if (cardState.hasReachedSwipeLimit) {
                              ref.read(popUpProvider.notifier).showPopUp(cardState.swipeResetTime);
                            } else if (cardState.currentQuestion != null) {
                              notifier.toggleLiked(cardState.currentQuestion!);
                            }
                          },
                        ),
                        const SizedBox(width: 40),
                        // Share Icon
                        IconButton(
                          icon: const Icon(
                            Icons.ios_share,
                            color: Colors.white,
                            size: 30.0,
                          ),
                          onPressed: () {
                            if (cardState.currentQuestion != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Share feature coming soon!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Filter preferences icon
                  Positioned(
                    right: 10,
                    top: 10,
                    child: IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white, size: 32),
                      onPressed: _openPreferences,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Tutorial Overlay
        if (showTutorial)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Swipe left and right on cards to navigate!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.raleway(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _swipeAnimation,
                    child: const Icon(
                      Icons.swipe,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Tap the heart icon to like a card and save it for later!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.raleway(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: () {
                      tutorialNotifier.hideTutorial();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 10.0,
                      ),
                    ),
                    child: Text(
                      "Got it!",
                      style: GoogleFonts.raleway(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
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