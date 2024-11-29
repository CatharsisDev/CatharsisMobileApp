import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../questions_model.dart';
import '../questions_service.dart';
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
  final DateTime? swipeResetTime;

  CardState({
    required this.allQuestions,
    required this.likedQuestions,
    required this.seenQuestions,
    required this.currentCategory,
    required this.isLoading,
    required this.currentIndex,
    required this.swipeCount,
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
      swipeResetTime: swipeResetTime ?? this.swipeResetTime,
    );
  }

List<Question> get activeQuestions {
  // Normalize the current category while preserving spaces
  final normalizedCurrentCategory = currentCategory
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '') 
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize multiple spaces to single space
      .trim();

  List<Question> available = currentCategory == 'all'
      ? allQuestions
      : allQuestions.where((q) {
          // Normalize each question's category the same way
          final normalizedQuestionCategory = q.category
              .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
              .replaceAll(RegExp(r'\s+'), ' ') // Normalize multiple spaces to single space
              .trim();
              
          return normalizedQuestionCategory == normalizedCurrentCategory;
        }).toList();

  return available;
}

  Question? get currentQuestion {
    final questions = activeQuestions;
    if (questions.isEmpty) return null;
    final validIndex = currentIndex.clamp(0, questions.length - 1);
    return questions[validIndex];
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
        )) {
    initializeApp();
  }

  final Ref ref;
  late Box<Question> likedBox;
  late Box swipeBox;

  Future<void> initializeApp() async {
    likedBox = await Hive.openBox<Question>('likedQuestions');
    swipeBox = await Hive.openBox('swipeData');
    await _loadLikedQuestions();
    await loadQuestions();
    await _checkSwipeReset();
  }

  Future<void> _loadLikedQuestions() async {
    final likedQuestions = likedBox.values.toList();
    state = state.copyWith(likedQuestions: likedQuestions);
  }

  Future<void> loadQuestions() async {
    state = state.copyWith(isLoading: true);
    try {
      final loadedQuestions = await QuestionsService.loadQuestions();
      var questions = List<Question>.from(loadedQuestions)..shuffle(Random());
      state = state.copyWith(
        allQuestions: questions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resetSwipeCount() async {
    state = state.copyWith(swipeCount: 0, swipeResetTime: null);
    await swipeBox.delete('swipe_limit_reached');
  }

  void updateCategory(String category) {
  // Normalize spaces while preserving them
  String normalizedCategory = category
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
      
  state = state.copyWith(
    currentCategory: normalizedCategory,
    currentIndex: 0,
    seenQuestions: [],
  );
}

  Future<void> _checkSwipeReset() async {
    final storedTimestamp = swipeBox.get('swipe_limit_reached') as String?;
    if (storedTimestamp != null) {
      final resetTime = DateTime.parse(storedTimestamp).add(RESET_DURATION);
      final now = DateTime.now();
      if (now.isAfter(resetTime)) {
        state = state.copyWith(swipeCount: 0, swipeResetTime: null);
        await swipeBox.delete('swipe_limit_reached');
      } else {
        state = state.copyWith(swipeResetTime: resetTime);
      }
    }
  }

  void handleCardSwiped(int index) async {
    if (state.hasReachedSwipeLimit) {
      ref.read(popUpProvider.notifier).showPopUp(state.swipeResetTime);
      return;
    }

    final questions = state.activeQuestions;
    if (questions.isEmpty) return;

    int normalizedIndex = index % questions.length;
    Question currentQuestion = questions[normalizedIndex];
    
    if (!state.likedQuestions.contains(currentQuestion)) {
      state = state.copyWith(
        seenQuestions: List.from(state.seenQuestions)..add(currentQuestion),
      );
    }

    final newSwipeCount = state.swipeCount + 1;
    state = state.copyWith(
      currentIndex: normalizedIndex,
      swipeCount: newSwipeCount,
    );

    if (newSwipeCount >= SWIPE_LIMIT) {
      final now = DateTime.now();
      await swipeBox.put('swipe_limit_reached', now.toIso8601String());
      final resetTime = now.add(RESET_DURATION);
      state = state.copyWith(swipeResetTime: resetTime);
      ref.read(popUpProvider.notifier).showPopUp(state.swipeResetTime);
    }
  }

  Future<void> toggleLiked(Question question) async {
    if (state.hasReachedSwipeLimit) {
      ref.read(popUpProvider.notifier).showPopUp(state.swipeResetTime);
      return;
    }

    final likedQuestions = List<Question>.from(state.likedQuestions);
    if (likedQuestions.any((q) => q.text == question.text && q.category == question.category)) {
      likedQuestions.removeWhere((q) => q.text == question.text && q.category == question.category);
    } else {
      likedQuestions.add(question);
    }

    await likedBox.clear();
    await likedBox.addAll(likedQuestions);
    state = state.copyWith(likedQuestions: likedQuestions);
  }
}

final cardStateProvider = StateNotifierProvider<CardStateNotifier, CardState>((ref) {
  return CardStateNotifier(ref);
});