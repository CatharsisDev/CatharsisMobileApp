import 'dart:math';
import 'package:catharsis_cards/services/user_beahvior_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../questions_model.dart';
import 'pop_up_provider.dart';
import 'package:catharsis_cards/services/questions_service.dart';
import '../services/user_beahvior_service.dart';

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

    filtered = filtered.where((q) => !likedQuestions.contains(q)).toList();
    final unseen = filtered.where((q) => !seenQuestions.contains(q)).toList();
    final seen   = filtered.where((q) =>  seenQuestions.contains(q)).toList();
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
    state = state.copyWith(likedQuestions: likedBox.values.toList());
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

  /// **Important**: Clone each `Question` so you're not re-using
  /// a HiveObject bound to another box.
  Future<void> toggleLiked(Question q) async {
    final list = List<Question>.from(state.likedQuestions);
    final normCat = _normalizeCategory(q.category);
    final exists = list.any((x) =>
        x.text == q.text && _normalizeCategory(x.category) == normCat);

    bool isLiking = !exists;

    if (exists) {
      list.removeWhere((x) =>
          x.text == q.text && _normalizeCategory(x.category) == normCat);
    } else {
      // create a brand‐new object for Hive
      list.add(Question(text: q.text, category: q.category));
    }

    // Track the like/unlike action
    await UserBehaviorService.trackQuestionLike(
      question: q,
      isLiked: isLiking,
    );

    await likedBox.clear();
    await likedBox.addAll(list);
    state = state.copyWith(likedQuestions: list);
  }
}

final cardStateProvider =
    StateNotifierProvider<CardStateNotifier, CardState>((ref) {
  return CardStateNotifier(ref);
});