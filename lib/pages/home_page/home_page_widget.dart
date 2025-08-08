import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:catharsis_cards/provider/auth_provider.dart';
import 'package:catharsis_cards/provider/theme_provider.dart';
import 'package:catharsis_cards/question_categories.dart';
import 'package:catharsis_cards/services/user_behavior_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
  final GlobalKey _cardBoundaryKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

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

  Future<void> _captureAndShareCard() async {
    try {
      // capture current card as image
      final boundary = _cardBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final cardImage = await boundary.toImage(
        pixelRatio: ui.window.devicePixelRatio,
      );

      // crop a bit from the top and adjust logo position
      final double cropTop = cardImage.height * 0.1;
      final double outputHeight = cardImage.height - cropTop;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, cardImage.width.toDouble(), outputHeight.toDouble()),
      );
      // shift the card up to crop off the top
      canvas.translate(0, -cropTop);
      canvas.drawImage(cardImage, Offset.zero, Paint());

      // load raw logo bytes and decode at full resolution
      final logoData = await rootBundle.load('assets/images/catharsis_word_only.png');
      final logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List());
      final logoFrame = await logoCodec.getNextFrame();
      final logoImage = logoFrame.image;
      // compute scaled dimensions preserving aspect ratio
      final logoWidth = cardImage.width * 0.7;
      final aspectRatio = logoImage.height / logoImage.width;
      final logoHeight = logoWidth * aspectRatio;
      // position logo a bit higher and account for cropped top
      final dx = (cardImage.width - logoWidth) / 2;
      final dy = outputHeight - 40 /* bottom padding */ - 200 /* gap below chip */ - logoHeight;
      final dstRect = Rect.fromLTWH(dx, dy, logoWidth, logoHeight);
      // draw the scaled logo
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
        dstRect,
        Paint(),
      );

      final picture = recorder.endRecording();
      final combinedImage = await picture.toImage(
        cardImage.width,
        outputHeight.toInt(),
      );
      final byteData = await combinedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final pngBytes = byteData!.buffer.asUint8List();

      // write to temporary file and share
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/card_share.png')
          .writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out this catharsis card!',
      );
    } catch (e) {
      print('Error sharing card image with logo: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Make status bar theme-aware
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  void _showExtraPackagePopUp(BuildContext context, DateTime? resetTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SwipeLimitPopup(
        resetTime: resetTime,
        onDismiss: () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(popUpProvider.notifier).hidePopUp();
          });
        },
        onPurchase: () {
          // ... existing purchase logic ...
        },
        onTimerEnd: () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(popUpProvider.notifier).hidePopUp();
          });
        },
      ),
    );
  }

  void _openPreferences() {
    final notifier = ref.read(cardStateProvider.notifier);
    final currentKeys = ref.read(cardStateProvider).selectedCategories;
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

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
                color: customTheme?.preferenceModalBackgroundColor ??
                    theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  if (ref.watch(themeProvider).themeName == 'light')
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Image.asset(
                            "assets/images/light_mode_preference_menu.png",
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: customTheme?.iconColor ?? theme.iconTheme.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Back button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios,
                                  color: theme.iconTheme.color, size: 24),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          // Title
                          Text(
                            'Categories',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.titleLarge?.color,
                              letterSpacing: 1.2,
                            ),
                          ),
                          // Clear All button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => tempSelectedKeys.clear()),
                              child: Text(
                                'Clear All',
                                style: TextStyle(
                                    fontFamily: 'Runtime',
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
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
                          final key =
                              QuestionCategories.normalizeCategory(display);
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
                                        ? (customTheme
                                                ?.preferenceItemSelectedColor
                                                ?.withOpacity(0.8) ??
                                            Colors.grey[700])
                                        : (customTheme
                                                ?.preferenceItemUnselectedColor ??
                                            Colors.grey[800]),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: customTheme
                                                ?.preferenceBorderColor ??
                                            Colors.grey[600]!,
                                        width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: Text(
                                            display,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Runtime',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: theme
                                                  .textTheme.bodyMedium?.color,
                                            ),
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
                              notifier
                                  .updateSelectedCategories(tempSelectedKeys);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme
                                      .extension<CustomThemeExtension>()
                                      ?.preferenceButtonColor ??
                                  theme.primaryColor,
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
                                color: theme
                                      .extension<CustomThemeExtension>()
                                      ?.buttonFontColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.25),
                                    offset: Offset(0, 1),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),
                  ) // end SafeArea
                ], // end children
              ), // end Stack
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
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final categoryColor = customTheme?.categoryChipColor ?? theme.primaryColor;
    final categoryIcon = _categoryIcons[category] ?? '📌';
    final themeName = ref.watch(themeProvider).themeName;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: categoryColor,
        image: themeName == 'light'
            ? const DecorationImage(
                image: AssetImage("assets/images/light_mode_preference_menu.png"),
                fit: BoxFit.cover,
                opacity: 1,
              )
            : null,
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
              color: customTheme?.buttonFontColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.25),
                  offset: Offset(0, 1),
                  blurRadius: 15,
                ),
              ],
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

    // Get theme data
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    final newCacheKey = _generateCacheKey(cardState);
    final didActiveQuestionsChange = _cacheKey != newCacheKey;
    if (_cachedQuestions == null || didActiveQuestionsChange) {
      final allActive = cardState.activeQuestions;
      final unseenQuestions = allActive.where((q) {
        final questionId = '${q.text}_${q.category}';
        return !cardState.seenQuestions.any(
                (seen) => seen.text == q.text && seen.category == q.category) &&
            !_displayedQuestionIds.contains(questionId);
      }).toList();

      _cachedQuestions = unseenQuestions.isEmpty ? allActive : unseenQuestions;
      _cacheKey = newCacheKey;

      if (_currentCardIndex >= _cachedQuestions!.length) {
        _currentCardIndex = 0;
      }
    }

    // Track displayed questions
    if (_cachedQuestions!.isNotEmpty &&
        _currentCardIndex < _cachedQuestions!.length) {
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
          // Theme-aware background
          Positioned.fill(
            child: Container(
              color: theme.scaffoldBackgroundColor,
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              key: _cardBoundaryKey,
              child: cardState.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: customTheme?.categoryChipColor ??
                              theme.primaryColor))
                  : FlutterFlowSwipeableStack(
                      controller: _cardController,
                      itemCount: questions.isEmpty ? 1 : questions.length,
                      itemBuilder: (ctx, i) {
                        if (questions.isEmpty) {
                          return Center(
                            child: Text(
                              'No questions available',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        final idx = i % questions.length;
                        final q = questions[idx];
                        return GestureDetector(
                          onDoubleTap: () {
                            HapticFeedback.lightImpact();
                            notifier.toggleLiked(q);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                image: (customTheme?.showBackgroundTexture ??
                                            false) &&
                                        (customTheme?.backgroundImagePath != null)
                                    ? DecorationImage(
                                        image: AssetImage(
                                            customTheme!.backgroundImagePath!),
                                        fit: BoxFit.cover,
                                        opacity: 0.4,
                                      )
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const SizedBox(height: 100),
                                        Flexible(
                                          child: Center(
                                            child: Text(
                                              q.text,
                                              style: TextStyle(
                                                fontFamily: 'Runtime',
                                                color: customTheme?.fontColor,
                                                fontSize: 32,
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
                          ),
                        );
                      },
                      onSwipe: (int previousIndex, int currentIndex, CardSwiperDirection direction) {
                        if (cardState.hasReachedSwipeLimit) {
                          _showExtraPackagePopUp(context, cardState.swipeResetTime);
                          return false;
                        }
                        if (questions.isNotEmpty && currentIndex < questions.length) {
                          final question = questions[currentIndex];
                          final activeQuestions = cardState.activeQuestions;
                          final actualIndex = activeQuestions.indexWhere((q) =>
                            q.text == question.text && q.category == question.category
                          );
                          if (actualIndex != -1) {
                            notifier.handleCardSwiped(
                              actualIndex,
                              direction: direction.name,
                              velocity: 1.0,
                            );
                          }
                        }
                        setState(() => _currentCardIndex += 1);
                        return true;
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
          ),
          // Top preferences and action buttons
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Share button moved to top left
                        InkWell(
                          onTap: () => _captureAndShareCard(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 44,
                            height: 44,
                            child: Image.asset(
                              'assets/images/share_icon.png',
                              width: 24,
                              height: 24,
                              color: customTheme?.likeAndShareIconColor ?? theme.iconTheme.color,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        // Like button moved to top left
                        InkWell(
                          onTap: () {
                            if (cardState.hasReachedSwipeLimit) {
                              ref.read(popUpProvider.notifier).showPopUp(cardState.swipeResetTime);
                            } else if (currentQuestion != null) {
                              HapticFeedback.lightImpact();
                              notifier.toggleLiked(currentQuestion);
                            }
                          },
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 44,
                            height: 44,
                            child: Image.asset(
                              'assets/images/heart_icon.png',
                              width: 28,
                              height: 28,
                              color: isCurrentLiked
                                  ? Colors.red
                                  : (customTheme?.likeAndShareIconColor ?? theme.iconTheme.color),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Existing preferences button
                    InkWell(
                      onTap: _openPreferences,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: customTheme?.iconCircleColor ?? Colors.white.withOpacity(0.1),
                        ),
                        child: Image.asset(
                          'assets/images/preferences_icon.png',
                          width: 24,
                          height: 24,
                          color: customTheme?.iconColor ?? theme.iconTheme.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom navigation
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
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Home",
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: theme.textTheme.bodyMedium?.color,
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
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Profile",
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
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
          // Tutorial overlay (commented out but keeping for reference)
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
                        backgroundColor: theme.primaryColor,
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

