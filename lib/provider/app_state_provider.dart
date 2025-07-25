import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../questions_model.dart';
import 'pop_up_provider.dart';
import 'auth_provider.dart';
import 'package:catharsis_cards/services/questions_service.dart';
import 'package:catharsis_cards/services/user_behavior_service.dart';

const int SWIPE_LIMIT = 20;
const Duration RESET_DURATION = Duration(minutes: 20);

/// Normalize categories so that comparisons always match exactly.
String _normalizeCategory(String s) => s
    .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class CardState {
  final List<Question> allQuestions;
  final List<Question> likedQuestions;
  final List<Question> seenQuestions;
  final String currentCategory;
  final bool isLoading;
  final int currentIndex;
  final Set<String> selectedCategories;
  final DateTime? swipeResetTime;

  CardState({
    required this.allQuestions,
    required this.likedQuestions,
    required this.seenQuestions,
    required this.currentCategory,
    required this.isLoading,
    required this.currentIndex,
    required this.selectedCategories,
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
    );
  }

  List<Question> get activeQuestions {
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

    // Don't filter out seen questions - this was causing the card switching issue
    // Instead, we'll handle seen questions differently
    return filtered;
  }

  Question? get currentQuestion {
    // This will be set from the widget based on the swiper's current index
    final list = activeQuestions;
    if (list.isEmpty) return null;
    // For now, return the first unseen question or the first question
    final unseenIndex = list.indexWhere((q) => !seenQuestions.contains(q));
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
        )) {
    _initialize();
  }

  final Ref ref;
  late Box<Question> likedBox;
  late Box swipeBox;
  late Box<Question> cacheBox;
  late Box<Question> seenBox;
  DateTime? _currentQuestionStartTime;

  Future<void> _initialize() async {
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

    await _loadLiked();
    await _loadSeenQuestions();
    await _loadPersonalizedQuestions();
    await _checkReset();
    _maybeGenerateMore();

    // Start tracking session
    await UserBehaviorService.startSession();
    _currentQuestionStartTime = DateTime.now();

    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadLiked() async {
    // First load from local Hive
    final localLiked = likedBox.values.toList();
    state = state.copyWith(likedQuestions: localLiked);
    
    // Then sync with Firestore
    try {
      final firestoreLiked = await UserBehaviorService.getLikedQuestions();
      if (firestoreLiked.isNotEmpty) {
        // Merge with local and update
        final mergedSet = {...localLiked, ...firestoreLiked};
        final mergedList = mergedSet.toList();
        
        // Update local storage
        await likedBox.clear();
        await likedBox.addAll(mergedList);
        
        state = state.copyWith(likedQuestions: mergedList);
      }
    } catch (e) {
      print('Error syncing liked questions with Firestore: $e');
    }
  }

  Future<void> _loadSeenQuestions() async {
    final seenQuestions = seenBox.values.toList();
    state = state.copyWith(seenQuestions: seenQuestions);
  }

  Future<void> _loadCache() async {
    final cached = cacheBox.values.toList();
    if (cached.isNotEmpty) {
      state = state.copyWith(allQuestions: cached..shuffle());
    } else {
      final qs = await QuestionsService.loadQuestionsWithAI();
      await cacheBox.clear();
      await cacheBox.addAll(qs);
      state = state.copyWith(allQuestions: qs..shuffle());
    }
  }

  Future<void> _loadPersonalizedQuestions() async {
    try {
      // First load all questions
      final cached = cacheBox.values.toList();
      List<Question> allQuestions;
      
      if (cached.isNotEmpty) {
        allQuestions = cached;
      } else {
        allQuestions = await QuestionsService.loadQuestionsWithAI();
        await cacheBox.clear();
        await cacheBox.addAll(allQuestions);
      }
      
      // Then get personalized order
      final personalizedQuestions = await UserBehaviorService.getPersonalizedQuestions(
        allQuestions: allQuestions,
        count: allQuestions.length,
      );
      
      state = state.copyWith(allQuestions: personalizedQuestions);
    } catch (e) {
      print('Error loading personalized questions: $e');
      // Fallback to regular loading
      await _loadCache();
    }
  }

  void _maybeGenerateMore() {
    if (state.allQuestions.isEmpty) return;
    final pct = state.seenQuestions.length / state.allQuestions.length;
    if (pct > 0.8) {
      QuestionsService.loadQuestionsWithAI().then((newQs) {
        cacheBox.addAll(newQs);
        state = state.copyWith(allQuestions: [...state.allQuestions, ...newQs]);
      }).catchError((_) {});
    }
  }

  Future<void> _checkReset() async {
    final raw = swipeBox.get('swipe_limit_reached') as String?;
    if (raw != null) {
      final resetTime = DateTime.parse(raw).add(RESET_DURATION);
      if (DateTime.now().isAfter(resetTime)) {
        await swipeBox.delete('swipe_limit_reached');
        state = state.copyWith(swipeResetTime: null);
      } else {
        state = state.copyWith(swipeResetTime: resetTime);
      }
    }
  }

  void updateCategory(String cat) {
    final norm = _normalizeCategory(cat);
    state = state.copyWith(
      currentCategory: norm,
      selectedCategories: {norm},
      currentIndex: 0,
      seenQuestions: [],
    );
    // Clear seen questions when category changes
    seenBox.clear();
  }

  void updateSelectedCategories(Set<String> cats) {
    final normSet = cats.map(_normalizeCategory).toSet();
    state = state.copyWith(
      selectedCategories: normSet,
      currentIndex: 0,
      // Don't reset seen questions when changing categories
    );
    // Don't clear seen questions box
  }

  void handleCardSwiped(int index, {String direction = 'unknown', double velocity = 0.0}) {
    // Get the cached unseen questions from the widget
    final allActive = state.activeQuestions;
    final unseenQuestions = allActive.where((q) => 
      !state.seenQuestions.any((seen) => 
        seen.text == q.text && seen.category == q.category)
    ).toList();
    
    final qs = unseenQuestions.isEmpty ? allActive : unseenQuestions;
    if (qs.isEmpty || index >= qs.length) return;
    
    final currentQuestion = qs[index];
    
    // Track asynchronously without blocking
    () async {
      if (_currentQuestionStartTime != null) {
        final duration = DateTime.now().difference(_currentQuestionStartTime!).inSeconds;
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
      state = state.copyWith(seenQuestions: seen);
      
      // Persist to Hive
      seenBox.add(seenQuestion);
    }
    
    // Set start time for next question
    _currentQuestionStartTime = DateTime.now();
    
    _maybeGenerateMore();
  }

  void markQuestionAsSeen(Question question) {
    final seen = List<Question>.from(state.seenQuestions);
    if (!seen.any((q) => q.text == question.text && q.category == question.category)) {
      final seenQuestion = Question(
        text: question.text,
        category: question.category,
      );
      seen.add(seenQuestion);
      state = state.copyWith(seenQuestions: seen);
      seenBox.add(seenQuestion);
    }
  }

  void handleCardSwipedWithQuestion(Question question, {String direction = 'unknown', double velocity = 0.0}) {
    // Track asynchronously without blocking
    () async {
      if (_currentQuestionStartTime != null) {
        final duration = DateTime.now().difference(_currentQuestionStartTime!).inSeconds;
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
      state = state.copyWith(seenQuestions: seen);
      
      // Persist to Hive
      seenBox.add(seenQuestion);
    }
    
    // Set start time for next question
    _currentQuestionStartTime = DateTime.now();
    
    _maybeGenerateMore();
  }

  /// Toggle liked status without changing current card
  void toggleLiked(Question q) async {
    // Create normalized comparison for checking existence
    final normCat = _normalizeCategory(q.category);
    final currentLikes = state.likedQuestions;
    
    // Check if already liked
    final existingIndex = currentLikes.indexWhere((liked) =>
        liked.text == q.text && 
        _normalizeCategory(liked.category) == normCat);
    
    final isCurrentlyLiked = existingIndex != -1;
    
    // Create new list of likes
    List<Question> updatedLikes;
    if (isCurrentlyLiked) {
      // Remove from likes
      updatedLikes = List<Question>.from(currentLikes)
        ..removeAt(existingIndex);
    } else {
      // Add to likes (create new instance to avoid Hive issues)
      updatedLikes = [
        ...currentLikes,
        Question(text: q.text, category: q.category)
      ];
    }
    
    // Update state immediately for UI
    state = state.copyWith(likedQuestions: updatedLikes);
    
    // Update storage and Firestore asynchronously
    () async {
      try {
        // Update local Hive storage
        await likedBox.clear();
        await likedBox.addAll(updatedLikes);
        
        // Update Firestore
        await UserBehaviorService.trackQuestionLike(
          question: q,
          isLiked: !isCurrentlyLiked,
        );
      } catch (e) {
        print('Error updating likes: $e');
      }
    }();
  }

  Future<void> loadMoreQuestions() async {
    final newQs = await QuestionsService.loadQuestionsWithAI();
    final updatedQuestions = [...state.allQuestions, ...newQs];
    await cacheBox.addAll(newQs);
    state = state.copyWith(allQuestions: updatedQuestions);
  }

  // Add cleanup method for sign out
  Future<void> clearUserData() async {
    try {
      await likedBox.clear();
      await swipeBox.clear();
      await cacheBox.clear();
      await seenBox.clear();
      
      // Reset state
      state = CardState(
        allQuestions: [],
        likedQuestions: [],
        seenQuestions: [],
        currentCategory: 'all',
        isLoading: false,
        currentIndex: 0,
        selectedCategories: {},
      );
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }
}

final cardStateProvider = StateNotifierProvider<CardStateNotifier, CardState>((ref) {
  // Listen to auth state changes
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final previousUser = previous?.whenOrNull(data: (user) => user);
    final currentUser = next.whenOrNull(data: (user) => user);
    
    // If user changed (including null -> user or user -> null)
    if (previousUser?.uid != currentUser?.uid) {
      print('Auth state changed - User changed from ${previousUser?.uid} to ${currentUser?.uid}');
      // Force provider to rebuild
      ref.invalidateSelf();
    }
  });
  
  return CardStateNotifier(ref);
});