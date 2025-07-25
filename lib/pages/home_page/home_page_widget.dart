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
import '../theme_settings/theme_settings_page.dart';
import 'package:catharsis_cards/questions_model.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// Rest of your HomePageWidget code remains the same...

class HomePageWidget extends ConsumerStatefulWidget {
  const HomePageWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends ConsumerState<HomePageWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late CardSwiperController _cardController;
  late AnimationController _handController;
  late Animation<Offset> _swipeAnimation;
  int _currentCardIndex = 0;
  List<Question>? _cachedQuestions;
  String? _cacheKey;
  final Set<String> _displayedQuestionIds = {};

  @override
  bool get wantKeepAlive => true;

  final Map<String, Color> _categoryColors = {
    'Love and Intimacy': const Color.fromRGBO(42, 63, 44, 1),
    'Spirituality': const Color.fromRGBO(42, 63, 44, 1),
    'Society': const Color.fromRGBO(42, 63, 44, 1),
    'Interactions and Relationships': const Color.fromRGBO(42, 63, 44, 1),
    'Personal Development': const Color.fromRGBO(42, 63, 44, 1),
  };

  final Map<String, String> _categoryIcons = {
    'Love and Intimacy': '❤️',
    'Spirituality': '✨',
    'Society': '🌍',
    'Interactions and Relationships': '🤝',
    'Personal Development': '🌱',
  };

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
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final displayCats = QuestionCategories.getAllCategories();
        final tempSelectedKeys = Set<String>.from(currentKeys);

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 253, 240, 0.9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Categories',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 1.2,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => tempSelectedKeys.clear()),
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: displayCats.map((display) {
                          final key = QuestionCategories.normalizeCategory(display);
                          final isSelected = tempSelectedKeys.contains(key);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      tempSelectedKeys.remove(key);
                                    } else {
                                      tempSelectedKeys.add(key);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? const Color.fromRGBO(152, 117, 84, 0.1) 
                                        : const Color.fromRGBO(255, 253, 240, 1), 
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF8B4F4F), width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          display,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Runtime',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                              backgroundColor: const Color.fromRGBO(42, 63, 44, 1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Apply',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _generateCacheKey(CardState state) {
    return '${state.selectedCategories.join(',')}_${state.currentCategory}_${state.allQuestions.length}_${state.seenQuestions.length}';
  }

  Widget _buildCategoryChip(String category) {
    final categoryColor = _categoryColors[category] ?? const Color(0xFF5C4033);
    final categoryIcon = _categoryIcons[category] ?? '📌';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: categoryColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            categoryIcon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            category,
            style: TextStyle(
              fontFamily: 'Runtime',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Add this for AutomaticKeepAliveClientMixin
    final cardState = ref.watch(cardStateProvider);
    final notifier = ref.read(cardStateProvider.notifier);
    final tutorialState = ref.watch(tutorialProvider);
    final showTutorial = tutorialState.showInAppTutorial;

    final newCacheKey = _generateCacheKey(cardState);
    final didActiveQuestionsChange = _cacheKey != newCacheKey;
    if (_cachedQuestions == null || didActiveQuestionsChange) {
      final allActive = cardState.activeQuestions;
      final unseenQuestions = allActive.where((q) {
        final questionId = '${q.text}_${q.category}';
        return !cardState.seenQuestions.any((seen) =>
            seen.text == q.text && seen.category == q.category) &&
            !_displayedQuestionIds.contains(questionId);
      }).toList();

      _cachedQuestions = unseenQuestions.isEmpty ? allActive : unseenQuestions;
      _cacheKey = newCacheKey;

      if (_currentCardIndex >= _cachedQuestions!.length) {
        _currentCardIndex = 0;
      }
    }

    // Track displayed questions
    if (_cachedQuestions!.isNotEmpty && _currentCardIndex < _cachedQuestions!.length) {
      final currentQ = _cachedQuestions![_currentCardIndex];
      _displayedQuestionIds.add('${currentQ.text}_${currentQ.category}');
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
      if (next) _showExtraPackagePopUp(context, cardState.swipeResetTime);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFAF1E1),
                  const Color(0xFFFAF1E1).withOpacity(0.95),
                ],
              ),
            ),
            child: Opacity(
              opacity: 0.4,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/background_texture.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: cardState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : FlutterFlowSwipeableStack(
                  controller: _cardController,
                  itemCount: questions.isEmpty ? 1 : questions.length,
                  itemBuilder: (ctx, i) {
                    if (questions.isEmpty) {
                      return const Center(
                        child: Text(
                          'No questions available',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    final idx = i % questions.length;
                    final q = questions[idx];
                    return GestureDetector(
                      onDoubleTap: () => notifier.toggleLiked(q),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAF1E1),
                          image: DecorationImage(
                            image: AssetImage("assets/images/background_texture.png"),
                            fit: BoxFit.cover,
                            opacity: 0.4,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(height: 100),
                                  Flexible(
                                    child: Center(
                                      child: Text(
                                        q.text,
                                        style: const TextStyle(
                                          fontFamily: 'Runtime',
                                          color: Colors.black87,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          height: 1.3,
                                          letterSpacing: 2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      _buildCategoryChip(q.category),
                                      const SizedBox(height: 230),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onLeftSwipe: (i) {
                    if (questions.isNotEmpty && i < questions.length) {
                      final question = questions[i];
                      final activeQuestions = cardState.activeQuestions;
                      final actualIndex = activeQuestions.indexWhere((q) =>
                          q.text == question.text && q.category == question.category);

                      if (actualIndex != -1) {
                        notifier.handleCardSwiped(actualIndex, direction: 'left', velocity: 1.0);
                      }
                      Future.microtask(() => setState(() => _currentCardIndex += 1));
                    }
                  },
                  onRightSwipe: (i) {
                    if (questions.isNotEmpty && i < questions.length) {
                      final question = questions[i];
                      final activeQuestions = cardState.activeQuestions;
                      final actualIndex = activeQuestions.indexWhere((q) =>
                          q.text == question.text && q.category == question.category);

                      if (actualIndex != -1) {
                        notifier.handleCardSwiped(actualIndex, direction: 'right', velocity: 1.0);
                      }
                      setState(() => _currentCardIndex += 1);
                    }
                  },
                  loop: false,
                  onEnd: () => notifier.loadMoreQuestions(),
                  cardDisplayCount: 3,
                  scale: 1.0,
                  threshold: 0.4,
                  maxAngle: 0,
                  cardPadding: EdgeInsets.zero,
                  backCardOffset: Offset.zero,
                ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: _openPreferences,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF987554).withOpacity(0.1),
                                    ),
                      child: Image.asset(
                        'assets/images/preferences_icon.png',
                        width: 24,
                        height: 24,
                        color: const Color.fromRGBO(145, 121, 102, 0.867),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Share feature coming soon!'),
                            duration: Duration(seconds: 2),
                          ),
                        ),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 56,
                          height: 56,
                          child: Image.asset(
                            'assets/images/share_icon.png',
                            width: 24,
                            height: 24,
                            color: const Color.fromRGBO(145, 121, 102, 0.867),
                          ),
                        ),
                      ),
                      const SizedBox(width: 60),
                      InkWell(
                        onTap: () {
                          if (cardState.hasReachedSwipeLimit) {
                            ref.read(popUpProvider.notifier).showPopUp(cardState.swipeResetTime);
                          } else if (currentQuestion != null) {
                            notifier.toggleLiked(currentQuestion);
                          }
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 56,
                          height: 56,
                          child: Image.asset(
                            'assets/images/heart_icon.png',
                            width: 28,
                            height: 28,
                            color: isCurrentLiked ? Colors.red : const Color.fromRGBO(145, 121, 102, 0.867),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {},
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/home_icon.png',
                          width: 24,
                          height: 24,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Home",
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 80),
                  InkWell(
                    onTap: () => context.go('/profile'),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/profile_icon.png',
                          width: 24,
                          height: 24,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Profile",
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          /*
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
                      style: TextStyle(
                        fontFamily: 'Runtime',
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
                      "Double tap to like a card and save it for later!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(tutorialProvider.notifier).hideInAppTutorial();
                        ref.read(tutorialProvider.notifier).setTutorialSeen();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C4033),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        "Got it!",
                        style: TextStyle(
                          fontFamily: 'Runtime',
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
            */
        ],
      ),
    );
  }
}