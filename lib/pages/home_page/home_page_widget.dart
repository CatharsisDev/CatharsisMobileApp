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
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
  int _currentCardIndex = 0;
  List<Question>? _cachedQuestions;
  String? _cacheKey;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: ref.watch(themeProvider).themeName == 'dark'
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          ref.watch(themeProvider).themeName == 'dark'
              ? Brightness.light
              : Brightness.dark,
    ));
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
    final currentKeys = ref.read(cardStateProvider).selectedCategories;

    showModalBottomSheet(
      context: context,
      builder: (_) {
        final displayCats = QuestionCategories.getAllCategories();
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            setState(() {
                              _cachedQuestions = null;
                              _cacheKey = null;
                              _currentCardIndex = 0;
                            });
                            notifier.updateSelectedCategories(tempSelectedKeys);
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

  String _generateCacheKey(CardState state) {
    return '${state.selectedCategories.join(',')}_${state.currentCategory}_${state.allQuestions.length}';
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(cardStateProvider);
    final notifier = ref.read(cardStateProvider.notifier);
    final showTutorial = ref.watch(tutorialProvider);
    final tutorialNotifier = ref.read(tutorialProvider.notifier);

    // Generate cache key
    final newCacheKey = _generateCacheKey(cardState);

    // Update cached questions only if necessary
    if (_cachedQuestions == null || _cacheKey != newCacheKey) {
      _cachedQuestions = List<Question>.from(cardState.activeQuestions);
      _cacheKey = newCacheKey;
      _currentCardIndex = 0;
    }

    final questions = _cachedQuestions!;
    final currentQuestion = questions.isEmpty
        ? null
        : questions[_currentCardIndex % questions.length];
    final isCurrentLiked = currentQuestion != null &&
        cardState.likedQuestions.any((q) =>
            q.text == currentQuestion.text &&
            q.category == currentQuestion.category);

    ref.listen<bool>(popUpProvider, (_, next) {
      if (next) {
        _showExtraPackagePopUp(context, cardState.swipeResetTime);
      }
    });

    return Stack(
      children: <Widget>[
        cardState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Container(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
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
                    final idx = i;
                    final question = questions[idx];
                    // Map normalized category names to icon assets
                    final Map<String, String> _iconMap = {
                      'Love and Intimacy':
                          'assets/images/love_intimacy_icon.png',
                      'Spirituality': 'assets/images/spirituality_icon.png',
                      'Society': 'assets/images/society_icon.png',
                      'Interactions and Relationships':
                          'assets/images/interactions_relationships_icon.png',
                      'Personal Development':
                          'assets/images/personal_development_icon.png',
                    };
                    // Normalize and lookup icon path
                    final normalizedCat =
                        question.category.replaceAll('\n', ' ').trim();
                    final iconPath = _iconMap[normalizedCat] ?? '';
                    final q = question;
                    return GestureDetector(
                      onDoubleTap: () {
                        // actually toggle the like in your state
                        ref.read(cardStateProvider.notifier).toggleLiked(q);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: ref.watch(themeProvider).themeName == 'dark'
                                ? [
                                    const Color(0xFF1E1E1E),
                                    const Color(0xFF121212)
                                  ]
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
                        child: Stack(
                          children: [
                            if (iconPath.isNotEmpty)
                              Positioned(
                                top:
                                    140, // adjust as needed for spacing above question text
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Image.asset(
                                    iconPath,
                                    width: 100,
                                    height: 100,
                                  ),
                                ),
                              ),
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 100),
                                child: Text(
                                  q.text,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.raleway(
                                    color: Colors.white,
                                    //Size of Questions
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        offset: const Offset(2, 2),
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
                              bottom: 240,
                              child: Text(
                                q.category,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.raleway(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      offset: const Offset(2, 2),
                                      blurRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onLeftSwipe: (i) {
                    Future.delayed(Duration(milliseconds: 400), () {
                      notifier.handleCardSwiped(i,
                          direction: 'left', velocity: 1.0);
                      setState(() => _currentCardIndex = i + 1);
                    });
                  },
                  onRightSwipe: (i) {
                    Future.delayed(Duration(milliseconds: 400), () {
                      notifier.handleCardSwiped(i,
                          direction: 'right', velocity: 1.0);
                      setState(() => _currentCardIndex = i + 1);
                    });
                  },
                  loop: false,
                  onEnd: () => notifier.loadMoreQuestions(),
                  cardDisplayCount: 2,
                  scale: 1.0,
                  threshold: 0.5,
                  maxAngle: 0,
                  cardPadding: EdgeInsets.zero,
                  backCardOffset: Offset(0, 0),
                ),
              ),
        Positioned(
          right: 10,
          top: MediaQuery.of(context).padding.top + 10,
          child: IconButton(
            icon: const Icon(Icons.tune, color: Colors.white, size: 32),
            onPressed: _openPreferences,
          ),
        ),
        Positioned(
          // bottom navigation bar
          bottom: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.home, color: Colors.white, size: 24),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.person, color: Colors.white, size: 24),
                onPressed: () => context.go('/profile'),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 120,
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
                  color: isCurrentLiked ? Colors.red : Colors.white,
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
                icon:
                    const Icon(Icons.ios_share, color: Colors.white, size: 30),
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