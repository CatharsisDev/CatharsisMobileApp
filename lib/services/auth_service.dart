import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../questions_model.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// AuthService: Google + Apple (iOS native, Android provider with web fallback) + email
class AuthService {
  AuthService();
  
  static const String _appleAndroidServiceId = 'com.catharsis.cards.androidappleauth';
  static const String _appleAndroidRedirectUri =
      'https://catharsiscards.firebaseapp.com/__/auth/handler';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Expose the Firebase auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Apple Sign In helpers (nonce) ---
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = json.decode(decoded);
      if (map is Map<String, dynamic>) return map;
      return {};
    } catch (_) {
      return {};
    }
  }

  // --- Helpers ---
  Future<void> _handleFirstLogin(UserCredential result) async {
    if (result.additionalUserInfo?.isNewUser ?? false) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_seen_welcome');
      // If Apple returned a name on first sign-in, try to set displayName
      final user = result.user;
      final profile = result.additionalUserInfo?.profile;
      if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
        final givenName = profile?['given_name'] as String?;
        final familyName = profile?['family_name'] as String?;
        final full = [givenName, familyName].where((e) => e != null && e.trim().isNotEmpty).join(' ').trim();
        if (full.isNotEmpty) {
          await user.updateDisplayName(full);
        }
      }
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // force account picker
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
      await _handleFirstLogin(result);
      print('Google Sign-In successful: ${result.user?.email}');
      return result;
    } on FirebaseAuthException catch (e) {
      print('Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      final plat = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios');
      print('[AUTH] signInWithApple() start on $plat');

      // --- Web ---
      if (kIsWeb) {
        print('[APPLE WEB] Using Firebase popup provider');
        final provider = AppleAuthProvider()..addScope('email')..addScope('name');
        final result = await _auth.signInWithPopup(provider);
        print('[APPLE WEB] Firebase sign-in OK: uid=${result.user?.uid}');
        await _handleFirstLogin(result);
        return result.user;
      }

      if (Platform.isAndroid) {
        try {
          print('[APPLE ANDROID NATIVE] Trying Firebase signInWithProvider');
          final provider = AppleAuthProvider()..addScope('email')..addScope('name');
          final result = await _auth.signInWithProvider(provider);
          print('[APPLE ANDROID NATIVE] Firebase sign-in OK: uid=${result.user?.uid}');
          await _handleFirstLogin(result);
          return result.user;
        } on FirebaseAuthException catch (e) {
          // Common when Apple/Firebase config is not fully recognized on device.
          // Fall back to Apple web flow via sign_in_with_apple (Service ID + Redirect URI).
          final isInvalidCredential = e.code == 'invalid-credential' ||
              (e.message != null && e.message!.toLowerCase().contains('apple.com'));
          if (!isInvalidCredential) {
            rethrow;
          }
          print('[APPLE ANDROID NATIVE] Failed with ${e.code}: ${e.message}. Falling back to Apple web flow (ServiceID=$_appleAndroidServiceId)');
        } catch (e) {
          print('Android Apple provider unexpected error: $e. Falling back to Apple web flow...');
        }

        // --- Android path B (fallback): Apple web flow via sign_in_with_apple ---
        final rawNonce = _generateNonce();
        final hashedNonce = _sha256ofString(rawNonce);
        final state = _generateNonce(16);

        final appleIdCred = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
          nonce: hashedNonce,
          state: state,
          webAuthenticationOptions: WebAuthenticationOptions(
            clientId: _appleAndroidServiceId,
            redirectUri: Uri.parse(_appleAndroidRedirectUri),
          ),
        );

        // Check for null identityToken
        if (appleIdCred.identityToken == null) {
          throw FirebaseAuthException(
            code: 'invalid-credential',
            message: 'Apple did not provide a valid token. Please try again or contact support.',
          );
        }

        final payload = _decodeJwtPayload(appleIdCred.identityToken!);
        print('[APPLE ANDROID FALLBACK] clientId=$_appleAndroidServiceId redirect=$_appleAndroidRedirectUri');
        print('[APPLE ANDROID FALLBACK] idToken aud=${payload['aud']} iss=${payload['iss']} sub=${payload['sub']}');

        final oauth = OAuthProvider('apple.com').credential(
          idToken: appleIdCred.identityToken!,
          rawNonce: rawNonce,
          accessToken: appleIdCred.authorizationCode, // <- important for some devices
        );

        final result = await _auth.signInWithCredential(oauth);
        print('[APPLE ANDROID FALLBACK] Firebase sign-in OK: uid=${result.user?.uid}');
        await _handleFirstLogin(result);
        return result.user;
      }

      // --- iOS: native Sign in with Apple with nonce ---
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      final state = _generateNonce(16);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
        state: state,
      );

      // Check for null identityToken
      if (credential.identityToken == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Apple did not provide a valid token. Try signing out of Apple ID in Settings > Apple ID and sign in again.',
        );
      }

      final payload = _decodeJwtPayload(credential.identityToken!);
      print('[APPLE iOS] idToken aud=${payload['aud']} iss=${payload['iss']} sub=${payload['sub']}');

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken!,
        rawNonce: rawNonce,
        accessToken: credential.authorizationCode, // <- include auth code as accessToken
      );

      final UserCredential result = await _auth.signInWithCredential(oauthCredential);
      print('[APPLE iOS] Firebase sign-in OK: uid=${result.user?.uid}');
      await _handleFirstLogin(result);
      return result.user;
    } on SignInWithAppleAuthorizationException catch (e) {
      print('Apple authorization error: ${e.code} - ${e.message}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      // Surface helpful hints for common misconfigurations
      print('FirebaseAuthException (Apple): ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        // You might want to call: await _auth.fetchSignInMethodsForEmail(email) to guide a merge flow.
      }
      rethrow;
    } catch (e) {
      print('Apple Sign In Error: $e');
      rethrow;
    }
  }

  // ----------------
  // EMAIL/PASSWORD
  // ----------------
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Email Sign In Error: ${e.code} - ${e.message}');
      rethrow;
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
      await Future.delayed(const Duration(milliseconds: 100));
      return user;
    } on FirebaseAuthException catch (e) {
      print('Email Registration Error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  // ----------------
  // SIGN OUT
  // ----------------
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