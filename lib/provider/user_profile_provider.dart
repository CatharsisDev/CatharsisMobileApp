// provider/user_profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_service.dart';
import 'auth_provider.dart';

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final Ref ref;

  Future<void> _initialize() async {
    try {
      final profile = await UserProfileService.getUserProfile();
      if (mounted) {
        state = AsyncValue.data(profile);
      }
    } catch (e) {
      if (mounted) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> updateProfile({String? avatar, String? username}) async {
    try {
      await UserProfileService.updateProfile(
        avatar: avatar,
        username: username,
      );
      
      // Refresh the profile
      final updatedProfile = await UserProfileService.getUserProfile();
      if (mounted) {
        state = AsyncValue.data(updatedProfile);
      }
    } catch (e) {
      if (mounted) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _initialize();
  }

  void clearProfile() {
    UserProfileService.clearProfile();
    if (mounted) {
      state = const AsyncValue.data(null);
    }
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  // Listen to auth state changes
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final previousUser = previous?.whenOrNull(data: (user) => user);
    final currentUser = next.whenOrNull(data: (user) => user);
    
    // If user changed, refresh profile
    if (previousUser?.uid != currentUser?.uid) {
      ref.invalidateSelf();
    }
  });
  
  return UserProfileNotifier(ref);
});

// Convenience providers
final userAvatarProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).whenOrNull(data: (profile) => profile?.avatar);
});

final userUsernameProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).whenOrNull(data: (profile) => profile?.username);
});