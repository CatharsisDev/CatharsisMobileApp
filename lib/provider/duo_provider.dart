import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/duo_session.dart';
import '../questions_model.dart';
import '../services/duo_session_service.dart';
import '../services/duo_questions_service.dart';

/// The active session code. Null when not in a duo session.
final duoSessionCodeProvider = StateProvider<String?>((ref) => null);

/// Whether the current user is the host of the active session.
final duoIsHostProvider = StateProvider<bool>((ref) => false);

/// Real-time stream of the active session document.
/// Auto-disposes when no longer listened to.
final duoSessionStreamProvider =
    StreamProvider.autoDispose.family<DuoSession?, String>(
  (ref, code) => DuoSessionService.streamSession(code),
);

/// All completed sessions for a given user UID, newest first.
final duoPastSessionsProvider =
    FutureProvider.autoDispose.family<List<DuoSession>, String>(
  (ref, uid) => DuoSessionService.fetchPastSessions(uid),
);

/// Compatibility questions for Duo Mode.
/// On first access: loads the bundled CSV immediately, then calls the Cloud
/// Function (once per category) to add AI-generated compatibility questions.
/// Not autoDispose — the combined list stays cached in memory for the whole
/// app session so the AI calls never run more than once.
final duoQuestionsProvider = FutureProvider<List<Question>>((ref) {
  return DuoQuestionsService.loadAll();
});
