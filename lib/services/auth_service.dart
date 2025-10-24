import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  /// Expose the Firebase auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      // Now trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // If user cancels sign-in
      if (googleUser == null) {
        print('Google Sign-In cancelled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential result = await _auth.signInWithCredential(credential);
      
      print('Google Sign-In successful: ${result.user?.email}');
      
      // Check if this is a new user
      if (result.additionalUserInfo?.isNewUser ?? false) {
        print('New Google user detected - clearing welcome state');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('has_seen_welcome');
      }
      
      return result;
    } catch (e) {
      print('Google Sign-In Error: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

Future<User?> signInWithApple() async {
  try {
    print('Starting Apple Sign In...');
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    
    print('Apple credential received: ${credential.identityToken != null}');

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: credential.identityToken,
      accessToken: credential.authorizationCode,
    );
    
    print('Creating Firebase credential...');
    final UserCredential result = await _auth.signInWithCredential(oauthCredential);
    
    print('Firebase sign-in successful: ${result.user?.uid}');
    
    if (result.additionalUserInfo?.isNewUser ?? false) {
      print('New Apple user detected - clearing welcome state');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_seen_welcome');
    }
    
    return result.user;
  } catch (e) {
    print('Apple Sign In Error: $e');
    print('Error type: ${e.runtimeType}');
    rethrow; // Changed from return null
  }
}

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Email Sign In Error: ${e.code} - ${e.message}');
      throw e;
    }
  }

  Future<User?> registerWithEmail(String email, String password) async {
    try {
      // Clear SharedPreferences BEFORE registration (except theme data)
      print('Clearing all preferences before registration');
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys and filter out theme-related keys
      final allKeys = prefs.getKeys();
      final keysToRemove = allKeys.where((key) => !key.startsWith('theme_')).toList();
      
      // Remove all non-theme keys
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      // Clear Hive data
      print('Clearing all Hive data before registration');
      final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
      
      for (final prefix in boxPrefixes) {
        try {
          if (Hive.isBoxOpen(prefix)) {
            final box = Hive.box(prefix);
            await box.clear();
            await box.close();
          }
          await Hive.deleteBoxFromDisk(prefix);
        } catch (e) {
          print('Error clearing box $prefix: $e');
        }
        
        try {
          final defaultBox = '${prefix}_default';
          if (Hive.isBoxOpen(defaultBox)) {
            final box = Hive.box(defaultBox);
            await box.clear();
            await box.close();
          }
          await Hive.deleteBoxFromDisk(defaultBox);
        } catch (e) {
          // Ignore if box doesn't exist
        }
      }
      
      // Now register the user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('Verification email sent to ${user.email}');
      }
      
      print('New user registered successfully: ${result.user?.email}');
      
      // Force a small delay to ensure preferences are cleared
      await Future.delayed(Duration(milliseconds: 100));
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('Email Registration Error: ${e.code} - ${e.message}');
      throw e;
    }
  }

  Future<void> signOut() async {
    // Get current user ID before signing out
    final currentUserId = _auth.currentUser?.uid;
    
    // Clear user data but preserve theme
    if (currentUserId != null) {
      await _clearUserDataExceptTheme(currentUserId);
    }
    
    // Sign out from Google if signed in
    try {
      await _googleSignIn.disconnect(); // Use disconnect() instead of signOut() for complete removal
    } catch (e) {
      print('Error disconnecting from Google: $e');
      // Try signOut if disconnect fails
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('Error signing out from Google: $e');
      }
    }
    
    // Sign out from Firebase
    await _auth.signOut();
    
    // Clear all Hive boxes for the current user
    try {
      final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
      
      for (final prefix in boxPrefixes) {
        // Clear default boxes
        if (Hive.isBoxOpen(prefix)) {
          final box = Hive.box(prefix);
          await box.clear();
          await box.close();
        }
        
        // Clear user-specific boxes (check common patterns)
        final patterns = ['_default', '_temp'];
        for (final pattern in patterns) {
          final boxName = '$prefix$pattern';
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.clear();
            await box.close();
          }
        }
      }
    } catch (e) {
      print('Error clearing local data on sign out: $e');
    }
  }

  Future<void> _clearUserDataExceptTheme(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // List of keys to clear (excluding theme)
      final keysToClear = [
        'user_avatar',
        'user_username',
        'selected_categories',
        'liked_questions',
        'seen_questions',
        'has_seen_tutorial',
        'has_seen_welcome',
        'is_dark_mode', // Remove old theme key if exists
        'selected_theme', // Remove old theme key if exists
      ];
      
      // Clear specific keys
      for (final key in keysToClear) {
        await prefs.remove(key);
      }
      
      // Note: We're NOT clearing theme_$userId
      print('User data cleared successfully (theme preserved for user: $userId)');
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  // Helper method to clear all data including themes (for app reset)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear all Hive boxes
      final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
      
      for (final prefix in boxPrefixes) {
        try {
          if (Hive.isBoxOpen(prefix)) {
            final box = Hive.box(prefix);
            await box.clear();
            await box.close();
          }
          await Hive.deleteBoxFromDisk(prefix);
        } catch (e) {
          print('Error clearing box $prefix: $e');
        }
      }
      
      print('All app data cleared successfully');
    } catch (e) {
      print('Error clearing all data: $e');
    }
  }
}