import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../questions_model.dart';

class UserBehaviorService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track when a user views a question
  static Future<void> trackQuestionView({
    required Question question,
    required int viewDuration,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Log to Firebase Analytics
    await _analytics.logEvent(
      name: 'question_viewed',
      parameters: {
        'question_id': question.text.hashCode.toString(),
        'category': question.category,
        'view_duration': viewDuration,
        'user_id': user.uid,
      },
    );

    // Store in Firestore for AI training
    await _firestore
        .collection('user_behaviors')
        .doc(user.uid)
        .collection('views')
        .add({
      'question': question.toJson(),
      'timestamp': FieldValue.serverTimestamp(),
      'duration': viewDuration,
    });
  }

  // Track when a user likes a question
  static Future<void> trackQuestionLike({
    required Question question,
    required bool isLiked,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _analytics.logEvent(
      name: isLiked ? 'question_liked' : 'question_unliked',
      parameters: {
        'question_id': question.text.hashCode.toString(),
        'category': question.category,
        'user_id': user.uid,
      },
    );

    // Update user preferences
    await _updateUserPreferences(question.category, isLiked ? 1.0 : -0.5);
  }

  // Track swipe behavior
  static Future<void> trackSwipeBehavior({
    required Question question,
    required String direction, // 'left', 'right', 'up', 'down'
    required double swipeVelocity,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _analytics.logEvent(
      name: 'question_swiped',
      parameters: {
        'question_id': question.text.hashCode.toString(),
        'category': question.category,
        'direction': direction,
        'velocity': swipeVelocity,
        'user_id': user.uid,
      },
    );

    // Store detailed swipe data
    await _firestore
        .collection('user_behaviors')
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
  }

  // Update user's category preferences
  static Future<void> _updateUserPreferences(String category, double scoreChange) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      
      Map<String, dynamic> preferences = {};
      if (snapshot.exists && snapshot.data()!.containsKey('preferences')) {
        preferences = Map<String, dynamic>.from(snapshot.data()!['preferences']);
      }
      
      // Update category score
      double currentScore = preferences[category]?.toDouble() ?? 0.0;
      preferences[category] = (currentScore + scoreChange).clamp(-1.0, 1.0);
      
      transaction.set(userDoc, {
        'preferences': preferences,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
      if (!userDoc.exists || !userDoc.data()!.containsKey('preferences')) {
        return allQuestions..shuffle();
      }

      final preferences = Map<String, double>.from(
        userDoc.data()!['preferences'].map((k, v) => MapEntry(k, v.toDouble()))
      );

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
          .take(count * 0.7 ~/ 1)
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

  // Use a custom event name instead of the reserved "session_start"
  await _analytics.logEvent(name: 'app_session_start');
  
  await _firestore
      .collection('user_sessions')
      .doc(user.uid)
      .collection('sessions')
      .add({
    'startTime': FieldValue.serverTimestamp(),
    'deviceInfo': {
      // Add device info if needed
    },
  });
}

  // Get user insights for AI training
  static Future<Map<String, dynamic>> getUserInsights() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final insights = <String, dynamic>{};

    // Get viewing patterns
    final views = await _firestore
        .collection('user_behaviors')
        .doc(user.uid)
        .collection('views')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    // Analyze patterns
    final categoryViews = <String, int>{};
    final avgDuration = <String, double>{};
    
    for (final doc in views.docs) {
      final data = doc.data();
      final category = data['question']['category'] as String;
      final duration = data['duration'] as int;
      
      categoryViews[category] = (categoryViews[category] ?? 0) + 1;
      avgDuration[category] = ((avgDuration[category] ?? 0.0) + duration) / 2;
    }

    insights['categoryPreferences'] = categoryViews;
    insights['averageViewDuration'] = avgDuration;
    insights['totalViews'] = views.docs.length;

    return insights;
  }
  static final _random = Random();
}

// Extension to make tracking easier
extension QuestionTrackingExtension on Question {
  String get trackingId => '${category}_${text.hashCode}';
}