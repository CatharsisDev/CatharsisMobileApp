import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:catharsis_cards/provider/theme_provider.dart';
import 'package:catharsis_cards/question_categories.dart';
import 'package:catharsis_cards/services/user_behavior_service.dart';
import 'package:catharsis_cards/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/pop_up_provider.dart';
import '../../provider/tutorial_state_provider.dart';
import '../../provider/seen_cards_provider.dart';
import '/components/swipe_limit_popup.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:catharsis_cards/questions_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:catharsis_cards/services/ad_service.dart';
import 'package:catharsis_cards/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // Heart fill animation (top -> bottom)
  late AnimationController _heartFillController;
  late Animation<double> _heartFill;
  // Text pop animation
  late AnimationController _textPopController;
  late Animation<double> _textPopScale;
  String? _lastHeartKey; // to sync state when the visible card changes
  int _currentCardIndex = 0;
  List<Question>? _cachedQuestions;
  String? _cacheKey;
  // Double-tap detection fallback
  DateTime? _lastTapTime;
  Offset? _lastTapPos;
  static const _doubleTapMaxDelay = Duration(milliseconds: 300);
  static const _doubleTapMaxDistance = 24.0;
  // Guard: avoid re-prompting within the same app run (e.g., after logout/login)
  static bool _askedNotifThisRun = false;

  void _handleCardTap(Offset pos, Question q) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) <= _doubleTapMaxDelay &&
        _lastTapPos != null &&
        (pos - _lastTapPos!).distance <= _doubleTapMaxDistance) {
      HapticFeedback.lightImpact();
      ref.read(cardStateProvider.notifier).toggleLiked(q);
      _lastTapTime = null;
      _lastTapPos = null;
    } else {
      _lastTapTime = now;
      _lastTapPos = pos;
    }
  }
  final GlobalKey _cardBoundaryKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

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
    // Heart fill animation controller
    _heartFillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heartFill = CurvedAnimation(
      parent: _heartFillController,
      curve: Curves.easeInOut,
    );
    // Text pop animation controller
    _textPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _textPopScale = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(begin: 1.0, end: 1.18)
        .chain(CurveTween(curve: Curves.easeOutCubic)),
    weight: 50,
  ),
  TweenSequenceItem(
    tween: Tween(begin: 1.18, end: 0.97)
        .chain(CurveTween(curve: Curves.easeInOut)),
    weight: 25,
  ),
  TweenSequenceItem(
    tween: Tween(begin: 0.97, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut)),
    weight: 25,
  ),
]).animate(_textPopController);
    // Preload Android interstitial ads
    if (Platform.isAndroid) {
      AdService.preload();
    }
    // Ask for notification permission once when the user reaches Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _promptNotificationsOnce();
        }
      });
    });
  }

  Future<void> _promptNotificationsOnce() async {
    // Runtime guard so logging out/in during the same app run won't re-trigger a prompt
    if (_askedNotifThisRun) return;

    const askedKey = 'notif_prompted_after_welcome_v2';
    final prefs = await SharedPreferences.getInstance();

    // Don’t prompt if already asked before (persisted across launches)
    final askedAlready = prefs.getBool(askedKey) ?? false;
    if (askedAlready) {
      _askedNotifThisRun = true;
      return;
    }

    // Don’t prompt if already allowed
    final allowed = await NotificationService.areNotificationsEnabled();
    if (allowed) {
      await prefs.setBool(askedKey, true);
      _askedNotifThisRun = true;
      return;
    }

    bool granted = false;
    try {
      // Ask once. Implementation of NotificationService should NOT force-open settings.
      granted = await NotificationService.ensurePermission(
        prompt: true,
        openSettingsOnDeny: false, // DO NOT auto-open Settings from Home first-arrival
      );
    } catch (e) {
      // Fail silently and still mark as asked so we don't nag.
      debugPrint('Notification permission request error: $e');
    }

    // Mark that we asked (persisted + runtime guard)
    await prefs.setBool(askedKey, true);
    _askedNotifThisRun = true;

    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can enable notifications later in Settings.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    _handController.dispose();
    _heartFillController.dispose();
    _textPopController.dispose();
    super.dispose();
  }
  void _syncHeartForCard(Question? q, bool liked) {
    final key = q == null ? 'none' : '${q.category}_${q.text}';
    if (_lastHeartKey != key) {
      _lastHeartKey = key;
      // Snap to the correct state when the visible card changes (no animation)
      _heartFillController.value = liked ? 1.0 : 0.0;
    }
  }

  Widget _buildAnimatedHeart(
    bool isLiked,
    ThemeData theme,
    CustomThemeExtension? customTheme,
  ) {
    // Animate toward the target state for the CURRENT card
    if (isLiked &&
        _heartFillController.value != 1.0 &&
        _heartFillController.status != AnimationStatus.forward) {
      _heartFillController.forward();
    } else if (!isLiked &&
        _heartFillController.value != 0.0 &&
        _heartFillController.status != AnimationStatus.reverse) {
      _heartFillController.reverse();
    }

    // Keep icon size consistent with your other top‑bar icons
    const double iconSize = 32.0; // was 28, looked too big
    final Color baseColor =
        customTheme?.likeAndShareIconColor ??
        theme.iconTheme.color ??
        Colors.white;

    // Use a brand/secondary color for the filled state
    final Color fillColor = Colors.red;

    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: AnimatedBuilder(
          animation: _heartFill,
          builder: (context, _) {
            final double h = _heartFill.value.clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.center,
              children: [
                // 1) Filled heart revealed TOP -> BOTTOM
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: h,
                    child: Icon(
                      Icons.favorite,
                      size: iconSize,
                      color: fillColor,
                    ),
                  ),
                ),
                // 2) Outline on TOP so the border stays crisp
                Icon(
                  Icons.favorite_border,
                  size: iconSize,
                  color: baseColor,
                ),
              ],
            );
          },
        ),
      ),
    );
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

      // Determine a popover anchor rect for iPad (required) and harmless on iPhone.
      Rect originRect;
      final RenderBox? buttonBox =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (buttonBox != null && buttonBox.hasSize) {
        final Offset topLeft = buttonBox.localToGlobal(Offset.zero);
        originRect = Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          buttonBox.size.width,
          buttonBox.size.height,
        );
      } else {
        // Fallback: tiny rect at screen center so it's within the screen bounds.
        final Size screenSize = MediaQuery.of(context).size;
        originRect = Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height / 2),
          width: 1,
          height: 1,
        );
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out this catharsis card!',
        sharePositionOrigin: originRect,
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

  void _showExtraPackagePopUp(BuildContext context, DateTime? resetTime) async {
    // Check premium status first
    final subscriptionService = ref.read(subscriptionServiceProvider);
    if (subscriptionService.isPremium.value) {
      return;
    }
    
    final now = DateTime.now();
    final effectiveResetTime = (resetTime != null && resetTime.isAfter(now))
        ? resetTime
        : now.add(RESET_DURATION);
    
    // Save to provider
    ref.read(popUpProvider.notifier).showPopUp(effectiveResetTime);
    
    // Schedule notification (only if notifications are enabled)
    if (effectiveResetTime.isAfter(DateTime.now())) {
      final enabled = await NotificationService.areNotificationsEnabled();
      if (enabled) {
        await NotificationService.cancelCooldownNotification('999');
        await NotificationService.scheduleCooldownNotification(
          id: '999',
          delay: effectiveResetTime.difference(DateTime.now()),
        );
      }
    }
    
    // Ensure context is still mounted
    if (!mounted) return;
    
    // Show popup with proper context handling
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return SwipeLimitPopup(
          resetTime: effectiveResetTime,
          onDismiss: () {
  ref.read(popUpProvider.notifier).hidePopUp();
  Navigator.of(dialogContext).pop();
},
          onPurchase: () {
            // Safe pop
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          },
          onTimerEnd: () {
            ref.read(popUpProvider.notifier).hidePopUp();
            Future.delayed(const Duration(milliseconds: 100), () {
              // Check if dialog is still showing
              if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              }
            });
          },
        );
      },
    ).then((_) {
      // Cleanup when dialog closes
      if (mounted) {
        ref.read(popUpProvider.notifier).hidePopUp();
      }
    });
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
                                _lastTapTime = null;
                                _lastTapPos = null;
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
    return '${state.selectedCategories.join(',')}_${state.currentCategory}';
  }

  Widget _buildCategoryChip(String category) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final categoryColor = customTheme?.categoryChipColor ?? theme.primaryColor;
    final themeName = ref.watch(themeProvider).themeName;
    final chipTextColor = themeName == 'catharsis_signature'
        ? Colors.white
        : (customTheme?.buttonFontColor ?? theme.textTheme.bodyMedium?.color);

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
            category,
            style: TextStyle(
              fontFamily: 'Runtime',
              color: chipTextColor,
              fontSize: 14,
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
    // Listen to subscription changes
    final subscriptionService = ref.watch(subscriptionServiceProvider);
    final isPremium = subscriptionService.isPremium.value;
    final cardState = ref.watch(cardStateProvider);
    final notifier = ref.read(cardStateProvider.notifier);
    final tutorialState = ref.watch(tutorialProvider);
    final showTutorial = tutorialState.showInAppTutorial;
    final seenCardsCount = ref.watch(seenCardsProvider);

    // Get theme data
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    final double prefButtonSize = 44.0;
    final double prefIconScale = 0.56; // icon will be ~56% of the circle

    final categoriesKey = _generateCacheKey(cardState);
    final categoriesChanged = _cacheKey != categoriesKey;
    final providerList = cardState.activeQuestions;

    if (_cachedQuestions == null ||
        categoriesChanged ||
        (_cachedQuestions!.isEmpty && providerList.isNotEmpty)) {
      if (providerList.isNotEmpty) {
        _cachedQuestions = List<Question>.from(providerList);
        if (_currentCardIndex >= _cachedQuestions!.length) {
          _currentCardIndex = 0;
        }
      } else if (categoriesChanged || _cachedQuestions == null) {
        // Only reset to empty when categories changed or it's the first build.
        _cachedQuestions = <Question>[];
        _currentCardIndex = 0;
      }
      _cacheKey = categoriesKey;
    }

    final questions = _cachedQuestions!;
    final currentQuestion = questions.isEmpty
        ? null
        : questions[_currentCardIndex % questions.length];
    final isCurrentLiked = currentQuestion != null &&
        cardState.likedQuestions.any((q) =>
            q.text == currentQuestion.text &&
            q.category == currentQuestion.category);

    _syncHeartForCard(currentQuestion, isCurrentLiked);

    ref.listen<bool>(popUpProvider, (previous, next) {
      if (next) {
        // iOS-specific delay to ensure UI is ready
        if (Platform.isIOS) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _showExtraPackagePopUp(context, ref.read(cardStateProvider).swipeResetTime);
            }
          });
        } else {
          _showExtraPackagePopUp(context, ref.read(cardStateProvider).swipeResetTime);
        }
      }
    });
    ref.listen<AsyncValue<bool>>(isPremiumProvider, (previous, next) {
      next.whenData((isPremium) {
        if (isPremium) {
          // User just became premium - dismiss popup if showing
          Navigator.of(context).popUntil((route) {
            return route.settings.name != 'SwipeLimitPopup';
          });
          // Reset cooldown
          ref.read(cardStateProvider.notifier).resetCooldown();
        }
      });
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
                      key: ValueKey('stack_${_cacheKey ?? 'none'}'),
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
                        final q = questions[i];
                        return KeyedSubtree(
                          key: ValueKey('card_${q.category}_${q.text}'),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: () {
                              if (cardState.hasReachedSwipeLimit) {
                                // Show the same popup used elsewhere when the limit is hit
                                ref.read(popUpProvider.notifier).state = true;
                                return;
                              }
                              HapticFeedback.lightImpact();
                              notifier.toggleLiked(q);
                              _textPopController.forward(from: 0);
                            },
                            onTapUp: (details) {
                              _handleCardTap(details.localPosition, q);
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
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return SingleChildScrollView(
                                                  physics: const ClampingScrollPhysics(),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      minHeight: constraints.maxHeight * 0.6,
                                                      maxHeight: constraints.maxHeight * 0.8,
                                                    ),
                                                    child: Center(
                                                      child: AnimatedBuilder(
                                                        animation: _textPopScale,
                                                        builder: (context, child) {
                                                          return Transform.scale(
                                                            scale: _textPopScale.value,
                                                            child: child,
                                                          );
                                                        },
                                                        child: Padding(
                                                          padding: (() {
                                                            final width = MediaQuery.of(context).size.width;
                                                            final isSmallPhone = width < 380;
                                                            return EdgeInsets.symmetric(
                                                              horizontal: isSmallPhone ? width * 0.08 : width * 0.05,
                                                              vertical: 20,
                                                            );
                                                          })(),
                                                          child: (() {
                                                            final width = MediaQuery.of(context).size.width;
                                                            final height = MediaQuery.of(context).size.height;
                                                            final isSmallPhone = width < 380;
                                                            final baseFontSize = isSmallPhone
                                                                ? width * 0.072
                                                                : height > 820
                                                                    ? width * 0.080
                                                                    : width * 0.075;
                                                            final minFontSize = isSmallPhone ? 16.0 : 18.0;
                                                            return AutoSizeText(
                                                              q.text,
                                                              style: TextStyle(
                                                                fontFamily: 'Runtime',
                                                                color: customTheme?.fontColor,
                                                                fontSize: baseFontSize,
                                                                fontWeight: FontWeight.bold,
                                                                height: isSmallPhone ? 1.32 : 1.22,
                                                                letterSpacing: isSmallPhone ? 1.1 : 1.4,
                                                              ),
                                                              textAlign: TextAlign.center,
                                                              maxLines: 10,
                                                              minFontSize: minFontSize,
                                                              stepGranularity: 0.4,
                                                              overflow: TextOverflow.visible,
                                                            );
                                                          })(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              _buildCategoryChip(q.category),
                                              (() {
                                                final h = MediaQuery.of(context).size.height;
                                                final bottomInset = MediaQuery.of(context).padding.bottom;
                                                return SizedBox(
                                                  height: h < 650
                                                      ? h * 0.12
                                                      : h * 0.09 + bottomInset,
                                                );
                                              })(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      onSwipe: (int previousIndex, int currentIndex, CardSwiperDirection direction) {
                        if (cardState.hasReachedSwipeLimit) {
                          final resetTime = cardState.swipeResetTime ?? DateTime.now().add(RESET_DURATION);
                          
                          // iOS-specific: Use microtask to ensure state updates properly
                          if (Platform.isIOS) {
                            Future.microtask(() {
                              ref.read(popUpProvider.notifier).state = true;
                            });
                          } else {
                            ref.read(popUpProvider.notifier).state = true;
                          }
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

                          AdService.onSwipeAndMaybeShow(context);
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
            top: MediaQuery.of(context).padding.top + 10, // Fixed position from top
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Share button
                    InkWell(
                      key: _shareButtonKey,
                      onTap: () => _captureAndShareCard(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 30,
                        height: 30,
                        child: Image.asset(
                          'assets/images/share_icon.png',
                          width: 30,
                          height: 30,
                          color: customTheme?.likeAndShareIconColor ?? theme.iconTheme.color,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Like button
                    InkWell(
                      onTap: () {
                        if (cardState.hasReachedSwipeLimit) {
                          ref.read(popUpProvider.notifier).state = true;
                        } else if (currentQuestion != null) {
                          HapticFeedback.lightImpact();
                          // Trigger animation immediately for better feedback
                          if (isCurrentLiked) {
                            _heartFillController.reverse();
                          } else {
                            _heartFillController.forward();
                          }
                          notifier.toggleLiked(currentQuestion);
                          _textPopController.forward(from: 0);
                        }
                      },
                      customBorder: const CircleBorder(),
                      child: _buildAnimatedHeart(isCurrentLiked, theme, customTheme),
                    ),
                  ],
                ),
                // Preferences button
                // Preferences button
                InkWell(
                  onTap: _openPreferences,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: prefButtonSize,
                    height: prefButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: customTheme?.iconCircleColor ?? Colors.white.withOpacity(0.1),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias, // ensure the icon never paints outside the circle
                    child: Image.asset(
                      'assets/images/preferences_icon.png',
                      width: prefButtonSize * prefIconScale,
                      height: prefButtonSize * prefIconScale,
                      fit: BoxFit.contain,
                      color: customTheme?.iconColor ?? theme.iconTheme.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom navigation
          Positioned(
            bottom: 0,   
            left: 0,
            right: 0,
            child: SafeArea(   
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
                      onTap: () => context.push('/profile'),
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
          ),
        ],
      ),
    );
  }
}
