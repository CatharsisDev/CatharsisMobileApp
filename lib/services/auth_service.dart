import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      
      // Check if this is a new user
      if (result.additionalUserInfo?.isNewUser ?? false) {
        print('New Google user detected - clearing welcome state');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('has_seen_welcome');
      }
      
      return result.user;
    } catch (e) {
      print('Google Sign In Error: $e');
      return null;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final UserCredential result = await _auth.signInWithCredential(oauthCredential);
      
      // Check if this is a new user
      if (result.additionalUserInfo?.isNewUser ?? false) {
        print('New Apple user detected - clearing welcome state');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('has_seen_welcome');
      }
      
      return result.user;
    } catch (e) {
      print('Apple Sign In Error: $e');
      return null;
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
      // Clear ALL Hive data before creating new user
      print('Clearing all Hive data before registration');
      
      // List of all possible box names (including user-specific ones)
      final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
      
      // Clear default boxes
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
        
        // Also try to clear any user-specific boxes
        try {
          // Check for boxes with common user ID patterns
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
      
      // Clear SharedPreferences too
      print('Registering new user - clearing welcome state');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear all preferences
      
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('New user registered successfully: ${result.user?.email}');
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Email Registration Error: ${e.code} - ${e.message}');
      throw e;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
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
}