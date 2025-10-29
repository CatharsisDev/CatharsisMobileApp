import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../questions_model.dart';

class UserBehaviorService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? _lastTrackedId;
  static DateTime? _lastTrackTime;

static Future<void> trackQuestionView({
  required Question question,
  required int viewDuration,
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  // Debounce: prevent same card within 4 seconds
  final trackingId = question.trackingId;
  final now = DateTime.now();
  if (_lastTrackedId == trackingId && 
      _lastTrackTime != null && 
      now.difference(_lastTrackTime!).inSeconds < 4) {
    print('[SKIP] Already tracked recently: $trackingId');
    return;
  }
  
  _lastTrackedId = trackingId;
  _lastTrackTime = now;

  try {
    // Store in Firestore for AI training
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('views')
        .add({
      'question': question.toJson(),
      'timestamp': FieldValue.serverTimestamp(),
      'duration': viewDuration,
    });

    print('[TRACK] Question viewed: ${question.text}, duration: $viewDuration');
    
    // Mark card as seen once (handles Firestore increment)
    await markCardSeenOnce(question);
  } catch (e) {
    print('Error tracking question view: $e');
  }
}

  // Get the total number of cards the user has seen
  static Future<int> getSeenCardsCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null && userDoc.data()!.containsKey('seenCardsCount')) {
        final count = userDoc.data()!['seenCardsCount'];
        return count is int ? count : 0;
      }

      return 0;
    } catch (e) {
      print('Error getting seen cards count: $e');
      return 0;
    }
  }

  // Increment the counter only once per question per user
  static Future<void> markCardSeenOnce(Question question) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final seenDoc = userDoc.collection('seen_cards').doc(question.trackingId);

    try {
      await _firestore.runTransaction((tx) async {
        final seenSnap = await tx.get(seenDoc);

        // Only count if this question hasn't been marked as seen yet
        if (!seenSnap.exists) {
          tx.set(seenDoc, {
            'firstSeenAt': FieldValue.serverTimestamp(),
            'questionId': question.trackingId,
            'category': question.category,
          });

          tx.set(
            userDoc,
            {
              'seenCardsCount': FieldValue.increment(1),
              'lastCountUpdate': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          
          print('[COUNT] Marked "${question.trackingId}" as seen once and incremented count');
        } else {
          print('[COUNT] Question "${question.trackingId}" already seen, skipping increment');
        }
      });
    } catch (e) {
      print('Error marking card seen once: $e');
    }
  }

  // Reset seen cards count (useful for testing)
  static Future<void> resetSeenCardsCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'seenCardsCount': 0,
        'lastCountUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('[COUNT] Seen cards count reset to 0');
    } catch (e) {
      print('Error resetting seen cards count: $e');
    }
  }

  // Track when a user likes a question
  static Future<void> trackQuestionLike({
    required Question question,
    required bool isLiked,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Store in Firestore
      await storeLikedQuestion(question: question, isLiked: isLiked);

      // Update user preferences
      await _updateUserPreferences(question.category, isLiked ? 1.0 : -0.5);
    } catch (e) {
      print('Error tracking question like: $e');
    }
  }

  static Future<List<Question>> getLikedQuestions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('liked_questions')
          .orderBy('likedAt', descending: true)
          .get();

      List<Question> likedQuestions = [];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data.containsKey('question') && data['question'] != null) {
            final question = Question.fromJson(Map<String, dynamic>.from(data['question']));
            likedQuestions.add(question);
          }
        } catch (e) {
          print('Error parsing liked question: $e');
          // Skip malformed documents
        }
      }
      
      return likedQuestions;
    } catch (e) {
      print('Error getting liked questions: $e');
      return [];
    }
  }

  static Future<void> storeLikedQuestion({
    required Question question,
    required bool isLiked,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Use a more reliable document ID
      final docId = '${question.category}_${question.text.hashCode.abs()}';
      final likedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('liked_questions')
          .doc(docId);

      if (isLiked) {
        // Add to liked questions
        await likedRef.set({
          'question': question.toJson(),
          'likedAt': FieldValue.serverTimestamp(),
          'questionId': docId,
        });
        print('[LIKE] Question liked and stored: ${question.text}');
      } else {
        // Remove from liked questions
        await likedRef.delete();
        print('[LIKE] Question unliked and removed: ${question.text}');
      }
    } catch (e) {
      print('Error storing liked question: $e');
    }
  }

  // Check if a question is liked
  static Future<bool> isQuestionLiked(Question question) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final docId = '${question.category}_${question.text.hashCode.abs()}';
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('liked_questions')
          .doc(docId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking if question is liked: $e');
      return false;
    }
  }

  // Track swipe behavior
  static Future<void> trackSwipeBehavior({
    required Question question,
    required String direction,
    required double swipeVelocity,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Store detailed swipe data
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('swipes')
          .add({
        'question': question.toJson(),
        'direction': direction,
        'velocity': swipeVelocity,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update preferences based on swipe
      if (direction == 'right') {
        await _updateUserPreferences(question.category, 0.5);
      } else if (direction == 'left') {
        await _updateUserPreferences(question.category, -0.3);
      }
    } catch (e) {
      print('Error tracking swipe behavior: $e');
    }
  }

  // Update user's category preferences
  static Future<void> _updateUserPreferences(
      String category, double scoreChange) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        Map<String, dynamic> preferences = {};
        if (snapshot.exists && snapshot.data() != null && snapshot.data()!.containsKey('preferences')) {
          preferences = Map<String, dynamic>.from(snapshot.data()!['preferences']);
        }

        // Update category score
        double currentScore = 0.0;
        if (preferences.containsKey(category) && preferences[category] != null) {
          currentScore = preferences[category] is num ? preferences[category].toDouble() : 0.0;
        }
        preferences[category] = (currentScore + scoreChange).clamp(-1.0, 1.0);

        transaction.set(
            userDoc,
            {
              'preferences': preferences,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });
    } catch (e) {
      print('Error updating user preferences: $e');
    }
  }

  // Get personalized questions based on user behavior
  static Future<List<Question>> getPersonalizedQuestions({
    required List<Question> allQuestions,
    int count = 20,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return allQuestions.take(count).toList();

    try {
      // Get user preferences
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc.data() == null || !userDoc.data()!.containsKey('preferences')) {
        return allQuestions..shuffle();
      }

      final preferencesData = userDoc.data()!['preferences'];
      if (preferencesData == null) {
        return allQuestions..shuffle();
      }

      final preferences = <String, double>{};
      (preferencesData as Map<String, dynamic>).forEach((key, value) {
        if (value is num) {
          preferences[key] = value.toDouble();
        }
      });

      // Score and sort questions
      final scoredQuestions = allQuestions.map((q) {
        double score = preferences[q.category] ?? 0.0;

        // Add randomness to prevent too much repetition
        score += (score * 0.3 * (0.5 - _random.nextDouble()));

        return MapEntry(q, score);
      }).toList();

      // Sort by score (highest first)
      scoredQuestions.sort((a, b) => b.value.compareTo(a.value));

      // Mix preferred and random questions
      final preferred = scoredQuestions
          .where((e) => e.value > 0)
          .take((count * 0.6).floor())
          .map((e) => e.key)
          .toList();

      final random = scoredQuestions
          .where((e) => e.value <= 0)
          .map((e) => e.key)
          .toList()
        ..shuffle();

      return [...preferred, ...random.take(count - preferred.length)];
    } catch (e) {
      print('Error getting personalized questions: $e');
      return allQuestions..shuffle();
    }
  }

  // Track session data
  static Future<void> startSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _analytics.logEvent(name: 'app_session_start');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .add({
        'userId': user.uid,
        'startTime': FieldValue.serverTimestamp(),
        'deviceInfo': {},
      });
    } catch (e) {
      print('Error starting session: $e');
    }
  }

  // Get user insights for AI training
  static Future<Map<String, dynamic>> getUserInsights() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final insights = <String, dynamic>{};

      // Get viewing patterns
      final views = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('views')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      // Analyze patterns
      final categoryViews = <String, int>{};
      final avgDuration = <String, double>{};

      for (final doc in views.docs) {
        try {
          final data = doc.data();
          if (data.containsKey('question') && data['question'] != null && 
              data.containsKey('duration') && data['duration'] != null) {
            final questionData = data['question'];
            if (questionData is Map && questionData.containsKey('category')) {
              final category = questionData['category'] as String;
              final duration = data['duration'] is int ? data['duration'] as int : 0;

              categoryViews[category] = (categoryViews[category] ?? 0) + 1;
              avgDuration[category] = ((avgDuration[category] ?? 0.0) + duration) / 2;
            }
          }
        } catch (e) {
          print('Error processing view data: $e');
        }
      }

      insights['categoryPreferences'] = categoryViews;
      insights['averageViewDuration'] = avgDuration;
      insights['totalViews'] = views.docs.length;
      insights['seenCardsCount'] = await getSeenCardsCount();

      return insights;
    } catch (e) {
      print('Error getting user insights: $e');
      return {};
    }
  }

  static final _random = Random();
}

// Extension to make tracking easier
extension QuestionTrackingExtension on Question {
  String get trackingId => '${category}_${text.hashCode.abs()}';
}