import 'package:catharsis_cards/provider/auth_provider.dart';
import 'package:catharsis_cards/provider/theme_provider.dart';
import 'package:catharsis_cards/question_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/components/gamecard_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/pop_up_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import '/components/swipe_limit_popup.dart';
import '../../provider/tutorial_state_provider.dart';
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

    // Initialize the hand swipe animation
    _handController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _swipeAnimation = Tween<Offset>(
      begin: Offset(-0.1, 0.0),
      end: Offset(0.1, 0.0),
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

  void _handleCategorySelection(String category, CardStateNotifier notifier) {
    notifier.updateCategory(
        category == 'All Categories' ? 'all' : category.replaceAll('\n', ' '));
    Navigator.pop(context); // Close the drawer after category selection
  }

  void _showExtraPackagePopUp(BuildContext context, DateTime? resetTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SwipeLimitPopup(
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
        );
      },
    );
  }

  void _openPreferences() {
    final notifier = ref.read(cardStateProvider.notifier);
    final current = ref.read(cardStateProvider).selectedCategories;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        // Use the official category list instead of extracting from questions
        final categories = QuestionCategories.getAllCategories();
        final tempSelected = Set<String>.from(current);

        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Filter Categories',
                        style: GoogleFonts.raleway(
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        )),
                  ),
                  ...categories.map((cat) {
                    return CheckboxListTile(
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
                    );
                  }).toList(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              tempSelected.clear();
                            });
                          },
                          child: Text('Clear All'),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: () {
                            notifier.updateSelectedCategories(tempSelected);
                            Navigator.pop(context);
                          },
                          child: Text('Apply'),
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
    ref.listen<bool>(popUpProvider, (previous, next) {
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
                    ? Color.fromARGB(235, 201, 197, 197)
                    : const Color.fromRGBO(208, 164, 180, 0.95),
            body: SafeArea(
              top: true,
              child: Stack(
                children: [
                  Container(
                    width: MediaQuery.sizeOf(context).width * 1.0,
                    height: MediaQuery.sizeOf(context).height * 1.029,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: ref.watch(themeProvider).themeName == 'dark'
                            ? [Color(0xFF1E1E1E), Color(0xFF121212)]
                            : ref.watch(themeProvider).themeName == 'light'
                                ? [
                                    Color.fromARGB(235, 201, 197, 197),
                                    Color.fromARGB(255, 255, 255, 255)
                                  ]
                                : [
                                    Color.fromARGB(235, 208, 164, 180),
                                    Color.fromARGB(255, 140, 198, 255)
                                  ],
                        stops: [0.0, 1.0],
                        begin: AlignmentDirectional(0.6, -0.34),
                        end: AlignmentDirectional(-1.0, 0.34),
                      ),
                    ),
                  ),
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
                                final normalizedIndex =
                                    index % questions.length;
                                final question = questions[normalizedIndex];
                                return Stack(
                                  children: [
                                    Align(
                                      alignment: AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 10,
                                              offset: Offset(0, 5),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: GamecardWidget(),
                                      ),
                                    ),
                                    Align(
                                      alignment: AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        width: 400.0,
                                        height: 400.0,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
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
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        offset:
                                                            Offset(2.0, 2.0),
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
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      offset: Offset(2.0, 2.0),
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
                                // Left swipe: skip without liking
                                notifier.handleCardSwiped(index);
                              },
                              onRightSwipe: (index) {
                                // Right swipe: like then advance
                                final questions = cardState.activeQuestions;
                                if (questions.isNotEmpty) {
                                  final q = questions[index % questions.length];
                                  notifier.toggleLiked(q);
                                }
                                notifier.handleCardSwiped(index);
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
                  // Heart and Share Icons below card stack
                  Positioned(
                    bottom: 50, // Changed from 100 to 50 to avoid overlap
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Heart Icon
                        IconButton(
                          icon: FaIcon(
                            isCurrentQuestionLiked
                                ? FontAwesomeIcons.solidHeart
                                : FontAwesomeIcons.heart,
                            color: isCurrentQuestionLiked
                                ? Colors.red
                                : Colors.white,
                            size: 30.0,
                          ),
                          onPressed: () {
                            if (cardState.hasReachedSwipeLimit) {
                              ref
                                  .read(popUpProvider.notifier)
                                  .showPopUp(cardState.swipeResetTime);
                            } else if (cardState.currentQuestion != null) {
                              notifier.toggleLiked(cardState.currentQuestion!);
                            }
                          },
                        ),
                        SizedBox(width: 40),
                        // Share Icon
                        IconButton(
                          icon: Icon(
                            Icons
                                .ios_share, // Changed from share_outlined to ios_share
                            color: Colors.white,
                            size: 30.0,
                          ),
                          onPressed: () {
                            if (cardState.currentQuestion != null) {
                              // TODO: Implement share functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
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
                      icon: Icon(Icons.tune, color: Colors.white, size: 32),
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
