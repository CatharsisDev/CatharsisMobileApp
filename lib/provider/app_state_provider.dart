import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../questions_model.dart';
import 'pop_up_provider.dart';
import 'auth_provider.dart';
import 'package:catharsis_cards/services/questions_service.dart';
import 'package:catharsis_cards/services/user_behavior_service.dart';
import 'package:catharsis_cards/services/notification_service.dart';
import 'package:catharsis_cards/services/subscription_service.dart';
import 'seen_cards_provider.dart';
import 'dart:io';
import 'dart:async';

const int SWIPE_LIMIT = 25;
const Duration RESET_DURATION = Duration(minutes: 60, seconds: 0);

/// Normalize categories so that comparisons always match exactly.
String _normalizeCategory(String s) => s
    .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _questionKey(Question q) =>
    '${_normalizeCategory(q.category)}|${q.text.trim()}';

class CardState {
  final List<Question> allQuestions;
  final List<Question> likedQuestions;
  final List<Question> seenQuestions;
  final String currentCategory;
  final bool isLoading;
  final int currentIndex;
  final Set<String> selectedCategories;
  final DateTime? swipeResetTime;

  /// How many cards the user has swiped since last reset
  final int swipeCount;
  final List<Question> sessionQuestions;

  // Caching for activeQuestions
  List<Question>? _cachedActiveQuestions;
  String? _lastCacheKey;

  CardState({
    required this.allQuestions,
    required this.likedQuestions,
    required this.seenQuestions,
    required this.currentCategory,
    required this.isLoading,
    required this.currentIndex,
    required this.selectedCategories,
    required this.swipeCount,
    required this.sessionQuestions,
    this.swipeResetTime,
  });

  // Add the getter here, right after constructor
  bool get hasReachedSwipeLimit {
    return swipeResetTime != null && DateTime.now().isBefore(swipeResetTime!);
  }

  CardState copyWith({
    List<Question>? allQuestions,
    List<Question>? likedQuestions,
    List<Question>? seenQuestions,
    String? currentCategory,
    bool? isLoading,
    int? currentIndex,
    Set<String>? selectedCategories,
    DateTime? swipeResetTime,
    int? swipeCount,
    List<Question>? sessionQuestions,
  }) {
    return CardState(
      allQuestions: allQuestions ?? this.allQuestions,
      likedQuestions: likedQuestions ?? this.likedQuestions,
      seenQuestions: seenQuestions ?? this.seenQuestions,
      currentCategory: currentCategory ?? this.currentCategory,
      isLoading: isLoading ?? this.isLoading,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      swipeResetTime: swipeResetTime ?? this.swipeResetTime,
      swipeCount: swipeCount ?? this.swipeCount,
      sessionQuestions: sessionQuestions ?? this.sessionQuestions,
    );
  }

  Set<String> get seenKeys => seenQuestions.map(_questionKey).toSet();
  Set<String> get likedKeys => likedQuestions.map(_questionKey).toSet();

  List<Question> get activeQuestions {
    // If we have a session snapshot, use it to keep the stack stable while swiping.
    if (sessionQuestions.isNotEmpty) return sessionQuestions;
    final cacheKey = '${selectedCategories.join(',')}|$currentCategory';
    if (_cachedActiveQuestions != null && _lastCacheKey == cacheKey) {
      return _cachedActiveQuestions!;
    }
    _cachedActiveQuestions = _buildActiveQuestions();
    _lastCacheKey = cacheKey;
    return _cachedActiveQuestions!;
  }

  List<Question> _buildActiveQuestions() {
    var filtered = allQuestions;
    if (selectedCategories.isNotEmpty) {
      final normSel = selectedCategories.map(_normalizeCategory).toSet();
      filtered = filtered.where((q) {
        return normSel.contains(_normalizeCategory(q.category));
      }).toList();
    } else if (currentCategory != 'all') {
      final normCat = _normalizeCategory(currentCategory);
      filtered = filtered.where((q) {
        return _normalizeCategory(q.category) == normCat;
      }).toList();
    }
    return filtered;
  }

  Question? get currentQuestion {
    // This will be set from the widget based on the swiper's current index
    final list = activeQuestions;
    if (list.isEmpty) return null;
    // For now, return the first unseen question or the first question
    final sk = seenKeys;
    final unseenIndex = list.indexWhere((q) => !sk.contains(_questionKey(q)));
    return list[unseenIndex >= 0 ? unseenIndex : 0];
  }

  int get startingIndex {
    final active = activeQuestions;
    if (active.isEmpty) return 0;
    // Find the first unseen question
    for (int i = 0; i < active.length; i++) {
      if (!seenQuestions.contains(active[i])) {
        return i;
      }
    }
    // If all are seen, start from the beginning
    return 0;
  }
}

class CardStateNotifier extends StateNotifier<CardState> {
  CardStateNotifier(this.ref)
      : super(CardState(
          allQuestions: [],
          likedQuestions: [],
          seenQuestions: [],
          currentCategory: 'all',
          isLoading: true,
          currentIndex: 0,
          selectedCategories: {},
          swipeCount: 0,
          sessionQuestions: [],
        )) {
    _initialize();
  }

  final Ref ref;
  late Box<Question> likedBox;
  late Box swipeBox;
  late Box<Question> cacheBox;
  late Box<Question> seenBox;
  DateTime? _currentQuestionStartTime;
  String? _lastTrackedQuestionId;
  DateTime? _lastTrackTime;
  bool _isDisposed = false;
  Timer? _rebuildTimer;

  final Set<String> _seenThisSession = <String>{};

  Future<void> _initialize() async {
    print('INITIALIZE CALLED - isDisposed: $_isDisposed, mounted: $mounted');
    if (!mounted || _isDisposed) return;
    
    state = state.copyWith(isLoading: true);
    
    // Define all box prefixes
    final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
    
    // Close all existing boxes
    for (final prefix in boxPrefixes) {
      // Try to close default boxes
      try {
        if (Hive.isBoxOpen(prefix)) {
          await Hive.box(prefix).close();
        }
      } catch (e) {
        print('Error closing box $prefix: $e');
      }
      
      // Try to close user-specific boxes (with common patterns)
      for (final suffix in ['_default', '_temp']) {
        final boxName = '$prefix$suffix';
        try {
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).close();
          }
        } catch (e) {
          // Ignore errors for non-existent boxes
        }
      }
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      print('Initializing boxes for user: $userId');
      
      // Close any existing user-specific boxes first
      for (final prefix in boxPrefixes) {
        final userBoxName = '${prefix}_$userId';
        try {
          if (Hive.isBoxOpen(userBoxName)) {
            await Hive.box(userBoxName).close();
          }
        } catch (e) {
          // Ignore
        }
      }
      
      // Open user-specific boxes
      likedBox = await Hive.openBox<Question>('likedQuestions_$userId');
      swipeBox = await Hive.openBox('swipeData_$userId');
      cacheBox = await Hive.openBox<Question>('cachedQuestions_$userId');
      seenBox = await Hive.openBox<Question>('seenQuestions_$userId');
      
      print('Boxes opened - Liked: ${likedBox.length}, Seen: ${seenBox.length}');
    } else {
      print('No user found, using default boxes');
      likedBox = await Hive.openBox<Question>('likedQuestions_default');
      swipeBox = await Hive.openBox('swipeData_default');
      cacheBox = await Hive.openBox<Question>('cachedQuestions_default');
      seenBox = await Hive.openBox<Question>('seenQuestions_default');
    }

    // Load persisted swipe count and cooldown
    final savedCount = (swipeBox.get('swipe_count') as int?) ?? 0;
    final rawReset = swipeBox.get('swipe_limit_reached') as String?;
    final loadedReset = rawReset != null
        ? DateTime.parse(rawReset).add(RESET_DURATION)
        : null;
    if (!mounted || _isDisposed) return;
    state = state.copyWith(
      swipeCount: savedCount,
      swipeResetTime: loadedReset,
    );

    if (!mounted) return;
    
    // Sync with Firestore as source of truth
    await _syncSwipeLimitFromFirestore();
    
    await _loadLiked();
    await _loadLikedFromFirestore();
    await _loadSeenQuestions();
    await _loadPersonalizedQuestions();
    _rebuildSessionQuestions();
    await _checkReset();
    _maybeGenerateMore();

    // Start tracking session
    await UserBehaviorService.startSession();
    _currentQuestionStartTime = DateTime.now();

    if (mounted) {
      state = state.copyWith(isLoading: false);
    }
  }

Future<void> _syncSwipeLimitFromFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || !mounted) return;
  
  // Check if user is premium
  final subscriptionService = ref.read(subscriptionServiceProvider);
  if (subscriptionService.isPremium.value) {
    print('[SYNC] User is premium - clearing any existing swipe limits');
    if (state.swipeResetTime != null || state.swipeCount != 0) {
      await swipeBox.delete('swipe_limit_reached');
      await swipeBox.put('swipe_count', 0);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'swipeCount': 0,
        'swipeResetTime': FieldValue.delete(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        state = state.copyWith(swipeCount: 0, swipeResetTime: null);
      }
    }
    return;
  }
  
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!mounted) return;
    
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      int firestoreCount = data['swipeCount'] as int? ?? 0;
      final firestoreResetStr = data['swipeResetTime'] as String?;
      
      DateTime? firestoreResetTime;
      if (firestoreResetStr != null) {
        firestoreResetTime = DateTime.parse(firestoreResetStr).add(RESET_DURATION);
        
        // Clear if expired
        if (firestoreResetTime.isBefore(DateTime.now())) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'swipeCount': 0,
            'swipeResetTime': FieldValue.delete(),
          }, SetOptions(merge: true));
          
          firestoreResetTime = null;
          firestoreCount = 0;
        }
      }
      
      // Update local
      await swipeBox.put('swipe_count', firestoreCount);
      if (firestoreResetTime != null) {
        await swipeBox.put('swipe_limit_reached', firestoreResetTime.subtract(RESET_DURATION).toIso8601String());
      } else {
        await swipeBox.delete('swipe_limit_reached');
      }
      
      if (mounted) {
        state = state.copyWith(
          swipeCount: firestoreCount,
          swipeResetTime: firestoreResetTime,
        );
      }
      
      print('[SYNC] Swipe limit synced from Firestore: count=$firestoreCount, reset=$firestoreResetTime');
    }
  } catch (e) {
    print('Error syncing swipe limit from Firestore: $e');
  }
}

  Future<void> _loadLiked() async {
    if (!mounted) return;
    
    final List<Question> localLiked = Hive.isBoxOpen(likedBox.name) ? likedBox.values.toList().cast<Question>() : <Question>[];
    
    if (mounted) {
      state = state.copyWith(likedQuestions: localLiked);
    }

    // Skip Firestore sync — load it when user explicitly opens the likes
  }

  Future<void> _loadSeenQuestions() async {
    if (!mounted) return;
    
    final List<Question> seenQuestions = Hive.isBoxOpen(seenBox.name) ? seenBox.values.toList().cast<Question>() : <Question>[];
    print('Loading seen questions from Hive: ${seenQuestions.length} items');
    if (mounted) {
      state = state.copyWith(seenQuestions: seenQuestions);
    }
  }

  Future<void> _loadCache() async {
    if (!mounted) return;
    
    final cached = Hive.isBoxOpen(cacheBox.name) ? cacheBox.values.toList() : [];
    if (cached.isNotEmpty) {
      if (mounted) {
        final List<Question> shuffled = cached.cast<Question>()..shuffle();
        state = state.copyWith(allQuestions: shuffled);
        _rebuildSessionQuestions();
      }
    } else {
      final qs = await QuestionsService.loadQuestionsWithAI();
      if (!mounted) return;
      
      if (Hive.isBoxOpen(cacheBox.name)) {
        await cacheBox.clear();
        await cacheBox.addAll(qs);
      }
      if (mounted) {
        state = state.copyWith(allQuestions: qs..shuffle());
        _rebuildSessionQuestions();
      }
    }
  }

  Future<void> _loadPersonalizedQuestions() async {
    if (!mounted) return;
    
    try {
      // First load all questions
      final cached = cacheBox.values.toList();
      List<Question> allQuestions;
      
      if (cached.isNotEmpty) {
        allQuestions = cached;
      } else {
        allQuestions = await QuestionsService.loadQuestionsWithAI();
        if (!mounted) return;
        
        await cacheBox.clear();
        await cacheBox.addAll(allQuestions);
      }
      
      // Then get personalized order
      final personalizedQuestions = await UserBehaviorService.getPersonalizedQuestions(
        allQuestions: allQuestions,
        count: allQuestions.length,
      );
      
      if (mounted) {
        state = state.copyWith(allQuestions: personalizedQuestions);
        _rebuildSessionQuestions();
      }
    } catch (e) {
      print('Error loading personalized questions: $e');
      // Fallback to regular loading
      await _loadCache();
    }
  }

  void _maybeGenerateMore() {
    if (!mounted) return;
    
    if (state.allQuestions.isEmpty) return;
    final pct = state.seenQuestions.length / state.allQuestions.length;
    if (pct > 0.8) {
      QuestionsService.loadQuestionsWithAI().then((newQs) {
        if (!mounted) return;
        
        cacheBox.addAll(newQs);
        if (mounted) {
          state = state.copyWith(allQuestions: [...state.allQuestions, ...newQs]);
        }
      }).catchError((_) {});
    }
  }

  Future<void> _checkReset() async {
    if (!mounted) return;
    
    // Premium users never have swipe limits
    final subscriptionService = ref.read(subscriptionServiceProvider);
    if (subscriptionService.isPremium.value) {
      // Clear any existing limits for premium users
      if (state.swipeResetTime != null || state.swipeCount != 0) {
        print('[CHECK_RESET] Premium user - clearing any stale cooldown');
        await swipeBox.delete('swipe_limit_reached');
        await swipeBox.put('swipe_count', 0);
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'swipeCount': 0,
            'swipeResetTime': FieldValue.delete(),
            'lastSwipe': FieldValue.delete(),
          }, SetOptions(merge: true));
        }
        
        if (mounted) {
          state = state.copyWith(
            swipeResetTime: null,
            swipeCount: 0,
          );
        }
      }
      return;
    }
    
    final raw = swipeBox.get('swipe_limit_reached') as String?;
    if (raw != null) {
      final resetTime = DateTime.parse(raw).add(RESET_DURATION);
      if (DateTime.now().isAfter(resetTime)) {
        // Cancel any pending notification
        final notificationId = swipeBox.get('notification_id') as String?;
        if (notificationId != null) {
          await NotificationService.cancelCooldownNotification(notificationId);
          await swipeBox.delete('notification_id');
        }
        
        await swipeBox.delete('swipe_limit_reached');
        await swipeBox.put('swipe_count', 0);
        
        // Also clear from Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'swipeCount': 0,
            'swipeResetTime': FieldValue.delete(),
            'lastSwipe': FieldValue.delete(),
          }, SetOptions(merge: true));
        }
        
        if (mounted) {
          state = state.copyWith(
            swipeResetTime: null,
            swipeCount: 0,
          );
        }
        // Ensure any swipe-limit popup is dismissed
        ref.read(popUpProvider.notifier).state = false;
      } else {
        if (mounted) {
          state = state.copyWith(swipeResetTime: resetTime);
        }
      }
    }
  }

  void _scheduleRebuild() {
  _rebuildTimer?.cancel();
  _rebuildTimer = Timer(Duration(milliseconds: 100), () {
    if (!_isDisposed && mounted) { // Add check here
      _rebuildSessionQuestions();
    }
  });
}

  void updateCategory(String cat) {
    if (!mounted) return;
    
    final norm = _normalizeCategory(cat);
    state = state.copyWith(
      currentCategory: norm,
      selectedCategories: {norm},
      currentIndex: 0,
    );
    _scheduleRebuild();
  }

  void updateSelectedCategories(Set<String> cats) {
    if (!mounted) return;
    
    final normSet = cats.map(_normalizeCategory).toSet();
    state = state.copyWith(
      selectedCategories: normSet,
      currentIndex: 0,
      sessionQuestions: [], // Clear session questions to force rebuild
    );
    _rebuildSessionQuestions(); // Rebuild immediately
  }

  Future<void> handleCardSwiped(int index, {String direction = 'unknown', double velocity = 0.0}) async {
    // Resolve premium with a safe default (non-premium until confirmed)
    final bool isPremium = ref.read(isPremiumProvider).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    final user = FirebaseAuth.instance.currentUser;

    if (!isPremium) {
      // Check for expired cooldown and show popup if still in cooldown
      await _checkReset();
      if (state.hasReachedSwipeLimit) {
        // Cooldown is active; UI listener will react to provider/state
        return;
      }
      if (!mounted) return;

      // Track swipe count and enforce limit
      final newCount = state.swipeCount + 1;
      if (newCount > SWIPE_LIMIT) {
        final now = DateTime.now();
        final resetTime = now.add(RESET_DURATION); // always fresh future time

        // Batch persist swipe count, limit reached, and last_swipe
        final batch = <String, dynamic>{
          'swipe_limit_reached': now.toIso8601String(),
          'swipe_count': newCount,
          'last_swipe': DateTime.now().toIso8601String(),
        };
        await swipeBox.putAll(batch);

        // Persist to Firestore
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'swipeCount': newCount,
            'swipeResetTime': now.toIso8601String(),
            'lastSwipe': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }

        // Update state FIRST so any UI reading it gets the fresh time
        if (mounted) {
          state = state.copyWith(
            swipeCount: newCount,
            swipeResetTime: resetTime,
          );
        }

        // Schedule notification for cooldown end
        await NotificationService.scheduleCooldownNotification(
          id: '999',
          delay: RESET_DURATION,
        );

        // iOS-specific: Ensure popup triggers after state propagation
        if (Platform.isIOS) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              ref.read(popUpProvider.notifier).showPopUp(resetTime);
            }
          });
        } else {
          // Non‑iOS: fall back to simple boolean trigger
          ref.read(popUpProvider.notifier).state = true;
        }

        return;
      } else {
        // Batch persist swipe count and last_swipe
        final batch = <String, dynamic>{
          'swipe_count': newCount,
          'last_swipe': DateTime.now().toIso8601String(),
        };
        await swipeBox.putAll(batch);
        
        // Persist to Firestore
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'swipeCount': newCount,
            'lastSwipe': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
        
        state = state.copyWith(swipeCount: newCount);
      }
    } else {
      // Premium users: ensure no stale cooldown/limit sticks around
      if (state.swipeResetTime != null || state.swipeCount != 0) {
        () async {
          await swipeBox.delete('swipe_limit_reached');
          await swipeBox.put('swipe_count', 0);
          
          // Clear from Firestore
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'swipeCount': 0,
              'swipeResetTime': FieldValue.delete(),
            }, SetOptions(merge: true));
          }
        }();
        if (mounted) {
          state = state.copyWith(swipeResetTime: null, swipeCount: 0);
        }
      }
    }

    // Get the cached unseen questions from the widget
    final allActive = state.activeQuestions;
    final unseenQuestions = allActive.where((q) =>
      !state.seenQuestions.any((seen) =>
        seen.text == q.text && seen.category == q.category)
    ).toList();

    final qs = unseenQuestions.isEmpty ? allActive : unseenQuestions;
    if (qs.isEmpty || index >= qs.length) return;

    final currentQuestion = qs[index];

    // Track asynchronously without blocking, with debouncing to prevent double logs
    () async {
      final trackingId = currentQuestion.trackingId;
      final now = DateTime.now();

      // Skip if same card tracked within last 2000ms
      if (_lastTrackedQuestionId == trackingId && 
    _lastTrackTime != null && 
    now.difference(_lastTrackTime!).inMilliseconds < 3500) {
  print('[SKIP] Double track prevented: $trackingId');
  return;
}

      _lastTrackedQuestionId = trackingId;
      _lastTrackTime = now;

      if (_currentQuestionStartTime != null) {
        final duration = now.difference(_currentQuestionStartTime!).inSeconds;
        await UserBehaviorService.trackQuestionView(
          question: currentQuestion,
          viewDuration: duration,
        );
      }

      await UserBehaviorService.trackSwipeBehavior(
        question: currentQuestion,
        direction: direction,
        swipeVelocity: velocity,
      );
    }();

    // Add to seen questions for persistence
    final seen = List<Question>.from(state.seenQuestions);
    if (!seen.any((q) => q.text == currentQuestion.text && q.category == currentQuestion.category)) {
      // Create a new instance to avoid Hive conflict
      final seenQuestion = Question(
        text: currentQuestion.text,
        category: currentQuestion.category,
      );
      seen.add(seenQuestion);
      if (mounted) {
        state = state.copyWith(seenQuestions: seen);
      }

      // Persist to Hive
      if (Hive.isBoxOpen(seenBox.name)) {
        await seenBox.put(seenQuestion.text.hashCode.toString(), seenQuestion);
      }
    }

    // Set start time for next question
    _currentQuestionStartTime = DateTime.now();

    _maybeGenerateMore();
  }

  void markQuestionAsSeen(Question question) {
    if (!mounted) return;
    
    final seen = List<Question>.from(state.seenQuestions);
    if (!seen.any((q) => q.text == question.text && q.category == question.category)) {
      final seenQuestion = Question(
        text: question.text,
        category: question.category,
      );
      seen.add(seenQuestion);
      if (mounted) {
        state = state.copyWith(seenQuestions: seen);
      }
      if (Hive.isBoxOpen(seenBox.name)) {
        seenBox.add(seenQuestion);
      }
    }
  }

  void handleCardSwipedWithQuestion(Question question, {String direction = 'unknown', double velocity = 0.0}) {
    if (!mounted) return;

    // Enforce the same premium/limit logic as handleCardSwiped
    final bool isPremium = ref.read(isPremiumProvider).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    final user = FirebaseAuth.instance.currentUser;

    if (!isPremium) {
      // Refresh cooldown in the background
      () async { await _checkReset(); }();

      // If already in cooldown, show popup and stop
      if (state.hasReachedSwipeLimit) {
        ref.read(popUpProvider.notifier).state = true;
        return;
      }

      final newCount = state.swipeCount + 1;
      if (newCount > SWIPE_LIMIT) {
        final now = DateTime.now();
        final resetTime = now.add(RESET_DURATION);

        // Batch persist swipe count, limit reached, and last_swipe asynchronously
        () async {
          final batch = <String, dynamic>{
            'swipe_limit_reached': now.toIso8601String(),
            'swipe_count': newCount,
            'last_swipe': DateTime.now().toIso8601String(),
          };
          await swipeBox.putAll(batch);
          
          // Persist to Firestore
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'swipeCount': newCount,
              'swipeResetTime': now.toIso8601String(),
              'lastSwipe': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          }
        }();

        if (mounted) {
          state = state.copyWith(
            swipeCount: newCount,
            swipeResetTime: resetTime,
          );
        }

        // Trigger popup for non‑premium users
        ref.read(popUpProvider.notifier).state = true;
        return;
      } else {
        // Batch increment swipe count and last_swipe asynchronously
        () async {
          final batch = <String, dynamic>{
            'swipe_count': newCount,
            'last_swipe': DateTime.now().toIso8601String(),
          };
          await swipeBox.putAll(batch);
          
          // Persist to Firestore
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'swipeCount': newCount,
              'lastSwipe': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          }
        }();
        if (mounted) {
          state = state.copyWith(swipeCount: newCount);
        }
      }
    } else {
      // Premium users: clear any stale cooldown/limit
      if (state.swipeResetTime != null || state.swipeCount != 0) {
        () async {
          await swipeBox.delete('swipe_limit_reached');
          await swipeBox.put('swipe_count', 0);
          
          // Clear from Firestore
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'swipeCount': 0,
              'swipeResetTime': FieldValue.delete(),
            }, SetOptions(merge: true));
          }
        }();
        if (mounted) {
          state = state.copyWith(swipeResetTime: null, swipeCount: 0);
        }
      }
    }
    
    // Track asynchronously without blocking, with debouncing to prevent double logs
    () async {
      final trackingId = question.trackingId;
      final now = DateTime.now();
      
      // Skip if same card tracked within 3.5 seconds
      if (_lastTrackedQuestionId == trackingId && 
          _lastTrackTime != null && 
          now.difference(_lastTrackTime!).inMilliseconds < 3500) {
        print('[SKIP] Double track prevented: $trackingId');
        return;
      }
      
      _lastTrackedQuestionId = trackingId;
      _lastTrackTime = now;
      
      if (_currentQuestionStartTime != null) {
        final duration = now.difference(_currentQuestionStartTime!).inSeconds;
        await UserBehaviorService.trackQuestionView(
          question: question,
          viewDuration: duration,
        );
      }

      await UserBehaviorService.trackSwipeBehavior(
        question: question,
        direction: direction,
        swipeVelocity: velocity,
      );
    }();
    
    // Add to seen questions for persistence
    final seen = List<Question>.from(state.seenQuestions);
    if (!seen.any((q) => q.text == question.text && q.category == question.category)) {
      // Create a new instance to avoid Hive conflict
      final seenQuestion = Question(
        text: question.text,
        category: question.category,
      );
      seen.add(seenQuestion);
      if (mounted) {
        state = state.copyWith(seenQuestions: seen);
      }
      
      // Persist to Hive
      if (Hive.isBoxOpen(seenBox.name)) {
        seenBox.add(seenQuestion);
      }
    }

    _currentQuestionStartTime = DateTime.now();
    
    _maybeGenerateMore();
  }

  /// Toggle liked status without changing current card
  void toggleLiked(Question q) async {
    if (!mounted) return;
    
    final normCat = _normalizeCategory(q.category);
    final currentLikes = state.likedQuestions;
    
    final existingIndex = currentLikes.indexWhere((liked) =>
        liked.text == q.text && 
        _normalizeCategory(liked.category) == normCat);
    
    final isCurrentlyLiked = existingIndex != -1;
    
    List<Question> updatedLikes;
    if (isCurrentlyLiked) {
      updatedLikes = List<Question>.from(currentLikes)..removeAt(existingIndex);
    } else {
      updatedLikes = [...currentLikes, Question(text: q.text, category: q.category)];
    }
    
    // Update state immediately
    if (mounted) {
      state = state.copyWith(likedQuestions: updatedLikes);
    }
    
    try {
      // Update Firestore first (source of truth)
      await UserBehaviorService.trackQuestionLike(
        question: q,
        isLiked: !isCurrentlyLiked,
      );
      
      // Then update local Hive storage
      if (Hive.isBoxOpen(likedBox.name)) {
        await likedBox.clear();
        await likedBox.addAll(updatedLikes);
      }
    } catch (e) {
      print('Error updating likes: $e');
      // Revert state on error
      if (mounted) {
        state = state.copyWith(likedQuestions: currentLikes);
      }
    }
  }

  Future<void> _loadLikedFromFirestore() async {
    if (!mounted) return;
    
    try {
      final firestoreLiked = await UserBehaviorService.getLikedQuestions();
      print('Loading liked questions from Firestore: ${firestoreLiked.length} items');
      
      // Merge with local Hive data (Firestore is source of truth)
      if (Hive.isBoxOpen(likedBox.name)) {
        await likedBox.clear();
        await likedBox.addAll(firestoreLiked);
      }
      
      if (mounted) {
        state = state.copyWith(likedQuestions: firestoreLiked);
      }
    } catch (e) {
      print('Error loading liked questions from Firestore: $e');
      // Keep local Hive data as fallback
    }
  }

  Future<void> loadMoreQuestions() async {
    if (!mounted) return;
    
    final newQs = await QuestionsService.loadQuestionsWithAI();
    if (!mounted) return;
    
    final updatedQuestions = [...state.allQuestions, ...newQs];
    if (Hive.isBoxOpen(cacheBox.name)) {
      await cacheBox.addAll(newQs);
    }
    if (mounted) {
      state = state.copyWith(allQuestions: updatedQuestions);
    }
  }

  // Add method to reset cooldown (e.g., if user pays to skip)
  Future<void> resetCooldown() async {
    if (!mounted) return;
    
    // Cancel any pending notification
    final notificationId = swipeBox.get('notification_id') as String?;
    if (notificationId != null) {
      await NotificationService.cancelCooldownNotification(notificationId);
      await swipeBox.delete('notification_id');
    }
    
    // Clear cooldown data
    await swipeBox.delete('swipe_limit_reached');
    await swipeBox.put('swipe_count', 0);
    
    // Clear from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'swipeCount': 0,
        'swipeResetTime': FieldValue.delete(),
        'lastSwipe': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
    
    if (mounted) {
      state = state.copyWith(
        swipeResetTime: null,
        swipeCount: 0,
      );
    }
  }

  // Add cleanup method for sign out
  Future<void> clearUserData() async {
    if (!mounted) return;
    
    try {
      _isDisposed = true;
      
      // Cancel any pending notifications
      final notificationId = swipeBox.get('notification_id') as String?;
      if (notificationId != null) {
        await NotificationService.cancelCooldownNotification(notificationId);
      }
      
      if (Hive.isBoxOpen(likedBox.name)) await likedBox.clear();
      if (Hive.isBoxOpen(swipeBox.name)) await swipeBox.clear();
      if (Hive.isBoxOpen(cacheBox.name)) await cacheBox.clear();
      if (Hive.isBoxOpen(seenBox.name)) await seenBox.clear();
      
      if (mounted) {
        state = CardState(
          allQuestions: [],
          likedQuestions: [],
          seenQuestions: [],
          currentCategory: 'all',
          isLoading: false,
          currentIndex: 0,
          selectedCategories: {},
          swipeCount: 0,
          sessionQuestions: [],
        );
      }
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  void _rebuildSessionQuestions() {
     if (_isDisposed || !mounted) return;

    var filtered = state.allQuestions;
    if (state.selectedCategories.isNotEmpty) {
      final normSel = state.selectedCategories.map(_normalizeCategory).toSet();
      filtered = filtered.where((q) {
        return normSel.contains(_normalizeCategory(q.category));
      }).toList();
    } else if (state.currentCategory != 'all') {
      final normCat = _normalizeCategory(state.currentCategory);
      filtered = filtered.where((q) {
        return _normalizeCategory(q.category) == normCat;
      }).toList();
    }

    // Exclude anything already seen or liked, and also de-duplicate by (category|text) key.
    final exclude = {...state.seenKeys, ...state.likedKeys};
    final seen = <String>{};
    final session = <Question>[];

    for (final q in filtered) {
      final key = _questionKey(q);
      if (exclude.contains(key)) continue;
      if (seen.add(key)) {
        session.add(q);
      }
    }

     if (!_isDisposed && mounted) {
    state = state.copyWith(
      sessionQuestions: session,
      currentIndex: 0,
    );
  }
}
  
  @override
  void dispose() {
    _isDisposed = true;
    _rebuildTimer?.cancel();
    super.dispose();
  }
}

final cardStateProvider = StateNotifierProvider<CardStateNotifier, CardState>((ref) {
  // Listen to auth state changes
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final previousUser = previous?.whenOrNull(data: (user) => user);
    final currentUser = next.whenOrNull(data: (user) => user);
    
    // Only invalidate on actual user change (login/logout), not on navigation
    if (previousUser?.uid != currentUser?.uid && 
        (previousUser == null || currentUser == null)) {
      print('Auth state changed - User signed in/out: ${previousUser?.uid} -> ${currentUser?.uid}');
      ref.invalidateSelf();
    }
  });
  return CardStateNotifier(ref);
});