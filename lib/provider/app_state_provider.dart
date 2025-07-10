import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../questions_model.dart';
import 'pop_up_provider.dart';
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

    // Don't filter out liked questions - we want to show them with heart filled
    final unseen = filtered.where((q) => !seenQuestions.contains(q)).toList();
    final seen = filtered.where((q) => seenQuestions.contains(q)).toList();
    return [...unseen, ...seen];
  }

  Question? get currentQuestion {
    final list = activeQuestions;
    if (list.isEmpty) return null;
    return list[currentIndex.clamp(0, list.length - 1)];
  }

  bool get hasReachedSwipeLimit => swipeResetTime != null && DateTime.now().isBefore(swipeResetTime!);
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
  DateTime? _currentQuestionStartTime;

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    likedBox = await Hive.openBox<Question>('likedQuestions');
    swipeBox = await Hive.openBox('swipeData');
    cacheBox = await Hive.openBox<Question>('cachedQuestions');

    await _loadLiked();
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
  }

  void updateSelectedCategories(Set<String> cats) {
    final normSet = cats.map(_normalizeCategory).toSet();
    state = state.copyWith(
      selectedCategories: normSet,
      currentIndex: 0,
      seenQuestions: [],
    );
  }

  void handleCardSwiped(int index, {String direction = 'unknown', double velocity = 0.0}) async {
    final qs = state.activeQuestions;
    if (qs.isEmpty) return;
    
    final i = index % qs.length;
    final currentQuestion = qs[i];
    
    // Track view duration if we have a start time
    if (_currentQuestionStartTime != null) {
      final duration = DateTime.now().difference(_currentQuestionStartTime!).inSeconds;
      await UserBehaviorService.trackQuestionView(
        question: currentQuestion,
        viewDuration: duration,
      );
    }

    // Track swipe behavior
    await UserBehaviorService.trackSwipeBehavior(
      question: currentQuestion,
      direction: direction,
      swipeVelocity: velocity,
    );
    
    final seen = List<Question>.from(state.seenQuestions);
    if (!seen.contains(currentQuestion)) seen.add(currentQuestion);
    
    state = state.copyWith(currentIndex: i, seenQuestions: seen);
    
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
}

final cardStateProvider =
    StateNotifierProvider<CardStateNotifier, CardState>((ref) {
  return CardStateNotifier(ref);
});