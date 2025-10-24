import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../questions_model.dart'; // Add this import

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  /// Expose the Firebase auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      
      print('Google Sign-In successful: ${result.user?.email}');
      
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
      rethrow;
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
      print('Clearing all preferences before registration');
      final prefs = await SharedPreferences.getInstance();
      
      final allKeys = prefs.getKeys();
      final keysToRemove = allKeys.where((key) => !key.startsWith('theme_')).toList();
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
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
      
      await Future.delayed(Duration(milliseconds: 100));
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('Email Registration Error: ${e.code} - ${e.message}');
      throw e;
    }
  }

  Future<void> signOut() async {
    final currentUserId = _auth.currentUser?.uid;
    
    if (currentUserId != null) {
      await _clearUserDataExceptTheme(currentUserId);
      
      print('Clearing Hive boxes for user: $currentUserId');
      try {
        final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
        
        for (final prefix in boxPrefixes) {
          final userBoxName = '${prefix}_$currentUserId'.toLowerCase();
          
          try {
            if (Hive.isBoxOpen(userBoxName)) {
              // Get box with correct type based on prefix
              if (prefix == 'likedQuestions' || prefix == 'cachedQuestions' || prefix == 'seenQuestions') {
                final box = Hive.box<Question>(userBoxName);
                await box.clear();
                await box.close();
              } else {
                // swipeData is a regular box
                final box = Hive.box(userBoxName);
                await box.clear();
                await box.close();
              }
              print('Cleared and closed Hive box: $userBoxName');
            }
            
            // Delete from disk
            await Hive.deleteBoxFromDisk(userBoxName);
            print('Deleted Hive box from disk: $userBoxName');
          } catch (e) {
            print('Error with box $userBoxName: $e');
          }
        }
      } catch (e) {
        print('Error clearing Hive boxes on sign out: $e');
      }
    }
    
    // Sign out from Google
    try {
      await _googleSignIn.disconnect();
      print('Disconnected from Google');
    } catch (e) {
      print('Error disconnecting from Google: $e');
      try {
        await _googleSignIn.signOut();
        print('Signed out from Google');
      } catch (e) {
        print('Error signing out from Google: $e');
      }
    }
    
    // Sign out from Firebase
    await _auth.signOut();
    print('Signed out from Firebase');
  }

  Future<void> _clearUserDataExceptTheme(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final keysToClear = [
        'user_avatar',
        'user_username',
        'selected_categories',
        'liked_questions',
        'seen_questions',
        'has_seen_tutorial',
        'has_seen_welcome',
        'has_seen_tutorial_$userId',
        'is_dark_mode',
        'selected_theme',
      ];
      
      for (final key in keysToClear) {
        await prefs.remove(key);
      }
      
      print('User data cleared successfully (theme preserved for user: $userId)');
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
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