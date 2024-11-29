import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'liked_cards_widget.dart' show LikedCardsWidget;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/questions_model.dart';

class LikedCardsModel extends FlutterFlowModel<LikedCardsWidget> {
  // Static list to store liked questions
  static final List<Question> likedQuestions = [];

  // Add a question to liked cards
  static void addQuestion(Question question) {
    if (!likedQuestions.contains(question)) {
      likedQuestions.add(question);
    }
  }

  // Remove a question from liked cards
  static void removeQuestion(Question question) {
    likedQuestions.remove(question);
  }

  // Check if a question is liked
  static bool isQuestionLiked(Question question) {
    return likedQuestions.contains(question);
  }

  // Get all liked questions
  static List<Question> getAllLikedQuestions() {
    return List.from(likedQuestions);
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}