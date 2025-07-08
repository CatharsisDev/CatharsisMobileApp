import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../questions_model.dart';
import 'package:catharsis_cards/services/questions_service.dart';
import 'pop_up_provider.dart';

const int SWIPE_LIMIT = 20;
const Duration RESET_DURATION = Duration(minutes: 20);

class CardState {
  final List<Question> allQuestions;
  final List<Question> likedQuestions;
  final List<Question> seenQuestions;
  final String currentCategory;
  final bool isLoading;
  final int currentIndex;
  final int swipeCount;
  final Set<String> selectedCategories; // ← New!
  final DateTime? swipeResetTime;

  CardState({
    required this.allQuestions,
    required this.likedQuestions,
    required this.seenQuestions,
    required this.currentCategory,
    required this.isLoading,
    required this.currentIndex,
    required this.swipeCount,
    required this.selectedCategories, // ← New!
    this.swipeResetTime,
  });

  CardState copyWith({
    List<Question>? allQuestions,
    List<Question>? likedQuestions,
    List<Question>? seenQuestions,
    String? currentCategory,
    bool? isLoading,
    int? currentIndex,
    int? swipeCount,
    Set<String>? selectedCategories, // ← New!
    DateTime? swipeResetTime,
  }) {
    return CardState(
      allQuestions: allQuestions ?? this.allQuestions,
      likedQuestions: likedQuestions ?? this.likedQuestions,
      seenQuestions: seenQuestions ?? this.seenQuestions,
      currentCategory: currentCategory ?? this.currentCategory,
      isLoading: isLoading ?? this.isLoading,
      currentIndex: currentIndex ?? this.currentIndex,
      swipeCount: swipeCount ?? this.swipeCount,
      selectedCategories:
          selectedCategories ?? this.selectedCategories, // ← New!
      swipeResetTime: swipeResetTime ?? this.swipeResetTime,
    );
  }

  List<Question> get activeQuestions {
  List<Question> filtered = allQuestions;

  if (selectedCategories.isNotEmpty) {
    filtered = filtered.where((q) {
      // Normalize both the question category and selected categories for comparison
      final normalizedQuestionCategory = q.category
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      return selectedCategories.any((selected) {
        final normalizedSelected = selected
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return normalizedQuestionCategory == normalizedSelected;
      });
    }).toList();
  } else if (currentCategory != 'all') {
    final normalizedCurrentCategory = currentCategory
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    filtered = filtered.where((q) {
      final normalizedQuestionCategory = q.category
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return normalizedQuestionCategory == normalizedCurrentCategory;
    }).toList();
  }

  filtered = filtered.where((q) => !likedQuestions.contains(q)).toList();
  List<Question> unseen = filtered.where((q) => !seenQuestions.contains(q)).toList();
  List<Question> seen = filtered.where((q) => seenQuestions.contains(q)).toList();

  return [...unseen, ...seen];
}

  Question? get currentQuestion {
    final list = activeQuestions;
    if (list.isEmpty) return null;
    final idx = currentIndex.clamp(0, list.length - 1);
    return list[idx];
  }

  bool get hasReachedSwipeLimit => swipeCount >= SWIPE_LIMIT;
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
          swipeCount: 0,
          selectedCategories: {}, // ← initialize empty set
        )) {
    initializeApp();
  }

  final Ref ref;
  late Box<Question> likedBox;
  late Box swipeBox;
  late Box<Question> cachedQuestionsBox;

  /// boots up Hive boxes, loads cache/likes, and triggers any pending reset
  Future<void> initializeApp() async {
    state = state.copyWith(isLoading: true);
    likedBox = await Hive.openBox<Question>('likedQuestions');
    swipeBox = await Hive.openBox('swipeData');
    cachedQuestionsBox = await Hive.openBox<Question>('cachedQuestions');

    await _loadLikedQuestions();
    await _loadCachedQuestions();
    await _checkSwipeReset();
    _generateMoreIfNeeded();

    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadLikedQuestions() async {
    state = state.copyWith(likedQuestions: likedBox.values.toList());
  }

  Future<void> _loadCachedQuestions() async {
    final cached = cachedQuestionsBox.values.toList();
    if (cached.isNotEmpty) {
      state = state.copyWith(allQuestions: cached..shuffle());
    } else {
      await _generateAndCacheQuestions();
    }
  }

  Future<void> _generateAndCacheQuestions() async {
    final newQs = await QuestionsService.loadQuestionsWithAI();
    await cachedQuestionsBox.clear();
    await cachedQuestionsBox.addAll(newQs);
    state = state.copyWith(allQuestions: newQs..shuffle());
  }

  void _generateMoreIfNeeded() {
    if (state.allQuestions.isEmpty) return;
    final seenPct = state.seenQuestions.length / state.allQuestions.length;
    if (seenPct > 0.8) {
      _generateAndCacheQuestions().catchError((e) {
        // ignore background errors
      });
    }
  }

  Future<void> resetSwipeCount() async {
    state = state.copyWith(swipeCount: 0, swipeResetTime: null);
    await swipeBox.delete('swipe_limit_reached');
  }

 void updateCategory(String category) {
  final normalizedCategory = category.replaceAll(RegExp(r'\s+'), ' ').trim();
  state = state.copyWith(
    currentCategory: normalizedCategory,
    currentIndex: 0,
    seenQuestions: [],
    // Sync the bottom‐sheet selection:
    selectedCategories: { normalizedCategory },
  );
}

  /// ← new: call this when the user hits “Apply” in your bottom-sheet
  void updateSelectedCategories(Set<String> cats) {
    state = state.copyWith(
      selectedCategories: cats,
      currentIndex: 0,
      seenQuestions: [],
    );
  }

  Future<void> _checkSwipeReset() async {
    final raw = swipeBox.get('swipe_limit_reached') as String?;
    if (raw != null) {
      final reset = DateTime.parse(raw).add(RESET_DURATION);
      if (DateTime.now().isAfter(reset)) {
        await resetSwipeCount();
      } else {
        state = state.copyWith(swipeResetTime: reset);
      }
    }
  }

  void handleCardSwiped(num index) async {
    final qs = state.activeQuestions;
    if (qs.isEmpty) return;

    // normalize index to an int
    final i = index.toInt() % qs.length;
    final currentQuestion = qs[i];

    // build a new seen‐list, only appending if it isn't already in there
    final alreadySeen = state.seenQuestions;
    final newSeen = alreadySeen.contains(currentQuestion)
        ? alreadySeen
        : [...alreadySeen, currentQuestion];

    state = state.copyWith(
      seenQuestions: newSeen,
      currentIndex: i,
    );

    _generateMoreIfNeeded();
  }

  Future<void> toggleLiked(Question q) async {
    final list = [...state.likedQuestions];
    final exists =
        list.any((x) => x.text == q.text && x.category == q.category);
    if (exists) {
      list.removeWhere((x) => x.text == q.text && x.category == q.category);
    } else {
      list.add(q);
    }
    await likedBox.clear();
    await likedBox.addAll(list);
    state = state.copyWith(likedQuestions: list);
  }

  Future<void> clearCache() async {
    await cachedQuestionsBox.clear();
    await _generateAndCacheQuestions();
  }

  Future<void> regenerateQuestions() async {
    await cachedQuestionsBox.clear();
    await _generateAndCacheQuestions();
  }
}

final cardStateProvider =
    StateNotifierProvider<CardStateNotifier, CardState>((ref) {
  return CardStateNotifier(ref);
});
