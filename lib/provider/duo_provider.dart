import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/duo_session.dart';
import '../services/duo_session_service.dart';

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
