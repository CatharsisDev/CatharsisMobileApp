import 'dart:math';
import 'package:catharsis_cards/provider/auth_provider.dart';
import 'package:catharsis_cards/provider/theme_provider.dart';
import 'package:catharsis_cards/question_categories.dart';
import 'package:catharsis_cards/services/user_behavior_service.dart';
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
  int _currentCardIndex = 0; // Track current card index locally

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

  /// UPDATED: normalize display → key mapping so the checkbox reflects
  void _openPreferences() {
    final notifier = ref.read(cardStateProvider.notifier);
    // these are your normalized keys already in state
    final currentKeys = ref.read(cardStateProvider).selectedCategories;
    
    showModalBottomSheet(
      context: context,
      builder: (_) {
        // display strings (may contain newlines)
        final displayCats = QuestionCategories.getAllCategories();
        // clone existing normalized keys
        final tempSelectedKeys = Set<String>.from(currentKeys);

        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Filter Categories',
                    style: GoogleFonts.raleway(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  // build a checkbox for each display string,
                  // but test and mutate against its normalized key
                  ...displayCats.map((display) {
                    final key = QuestionCategories.normalizeCategory(display);
                    return CheckboxListTile(
                      title: Text(display),
                      value: tempSelectedKeys.contains(key),
                      onChanged: (v) {
                        setState(() {
                          if (v == true)
                            tempSelectedKeys.add(key);
                          else
                            tempSelectedKeys.remove(key);
                        });
                      },
                    );
                  }).toList(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => tempSelectedKeys.clear()),
                          child: const Text('Clear All'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            notifier.updateSelectedCategories(
                                tempSelectedKeys);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD0A4B4),
                          ),
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

    // locate the current question based on our local index
    final questions = cardState.activeQuestions;
    final currentQuestion = questions.isEmpty
        ? null
        : questions[_currentCardIndex % questions.length];
    final isCurrentLiked = currentQuestion != null &&
        cardState.likedQuestions.any((q) =>
            q.text == currentQuestion.text &&
            q.category == currentQuestion.category);

    // popup trigger
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
                  // BG gradient
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
                                    Colors.white
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

                  // card stack
                  if (cardState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Align(
                      alignment: const AlignmentDirectional(0.0, 0.0),
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width * 4.0,
                        height: 485.0,
                        child: FlutterFlowSwipeableStack(
                          controller: _cardController,
                          itemCount: questions.isEmpty ? 1 : questions.length,
                          itemBuilder: (ctx, i) {
                            if (questions.isEmpty) {
                              return Center(
                                child: Text(
                                  'No questions available',
                                  style: GoogleFonts.raleway(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                              );
                            }
                            final idx = i % questions.length;
                            final q = questions[idx];

                            return Stack(
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: DecoratedBox(
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
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 400,
                                    height: 400,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                20, 20, 20, 60),
                                            child: Text(
                                              q.text,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.raleway(
                                                color: Colors.white,
                                                fontSize: 28,
                                                letterSpacing: 0.2,
                                                shadows: [
                                                  Shadow(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    offset:
                                                        const Offset(2, 2),
                                                    blurRadius: 2,
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
                                            q.category,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.raleway(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  offset:
                                                      const Offset(2, 2),
                                                  blurRadius: 2,
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
                          onLeftSwipe: (i) {
                            setState(() => _currentCardIndex = i + 1);
                            notifier.handleCardSwiped(
                              i,
                              direction: 'left',
                              velocity: 1.0,
                            );
                          },
                          onRightSwipe: (i) {
                            setState(() => _currentCardIndex = i + 1);
                            notifier.handleCardSwiped(
                              i,
                              direction: 'right',
                              velocity: 1.0,
                            );
                          },
                          loop: true,
                          cardDisplayCount: 4,
                          scale: 0.9,
                          threshold: 0.7,
                        ),
                      ),
                    ),

                  // heart & share
                  Positioned(
                    bottom: 50,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: FaIcon(
                            isCurrentLiked
                                ? FontAwesomeIcons.solidHeart
                                : FontAwesomeIcons.heart,
                            color:
                                isCurrentLiked ? Colors.red : Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            if (cardState.hasReachedSwipeLimit) {
                              ref
                                  .read(popUpProvider.notifier)
                                  .showPopUp(cardState.swipeResetTime);
                            } else if (currentQuestion != null) {
                              notifier.toggleLiked(currentQuestion);
                            }
                          },
                        ),
                        const SizedBox(width: 40),
                        IconButton(
                          icon: const Icon(
                            Icons.ios_share,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Share feature coming soon!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // prefs icon
                  Positioned(
                    right: 10,
                    top: 10,
                    child: IconButton(
                      icon: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _openPreferences,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // tutorial overlay
        if (showTutorial)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Swipe left and right on cards to navigate!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                  const SizedBox(height: 16),
                  Text(
                    "Tap the heart icon to like a card and save it for later!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => tutorialNotifier.hideTutorial(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "Got it!",
                      style: GoogleFonts.raleway(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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