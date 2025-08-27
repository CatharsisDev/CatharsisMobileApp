import 'dart:math';
import 'dart:io';
import 'package:catharsis_cards/questions_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:catharsis_cards/provider/theme_provider.dart';

class AccountDeletionService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> deleteAccountFlow(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (context != null && context.mounted) {
        _showSnack(context, 'No user is currently signed in.');
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog(context);
    if (!confirmed) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(
                'Deleting account...',
                style: TextStyle(fontFamily: 'Runtime'),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
      );

      // Try delete directly first
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading dialog
      }
      await _deleteUserDataAndAuth();
      if (context != null && context.mounted) {
        await _showDone(context);
      }
      return;
    } on FirebaseAuthException catch (e) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (e.code != 'requires-recent-login') {
        if (context != null && context.mounted) {
          _showSnack(context, 'Delete failed: ${e.message}');
        }
        return;
      }

      // Re-authenticate based on provider
      final providers = user.providerData.map((p) => p.providerId).toList();
      print('User providers: $providers');

      try {
        if (providers.contains('password')) {
          await _reauthWithPassword(context, user.email);
        } else if (providers.contains('google.com')) {
          await _reauthWithGoogle(context);
        } else if (providers.contains('apple.com')) {
          await _reauthWithApple(context);
        } else if (providers.contains('anonymous')) {
          print('Anonymous user - proceeding without reauth');
        } else {
          if (context != null && context.mounted) {
            _showSnack(context, 'Please sign in again to delete your account.');
          }
          return;
        }

        // Retry deletion after successful re-authentication
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Row(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text(
                    'Deleting account...',
                    style: TextStyle(fontFamily: 'Runtime'),
                  ),
                ],
              ),
            ),
          );
        }

        await _deleteUserDataAndAuth();

        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        if (context != null && context.mounted) {
          await _showDone(context);
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (e.code != 'cancelled' && context.mounted) {
          _showSnack(context, 'Delete failed: ${e.message}');
        }
      } catch (e) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (context != null && context.mounted) {
          _showSnack(context, 'Delete failed: $e');
        }
      }
      return;
    } catch (e) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading dialog
      }
      if (context != null && context.mounted) {
        _showSnack(context, 'Delete failed: $e');
      }
      return;
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[600]
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Text(
                'Delete account',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              // Body
              Text(
                'Are you sure you want to delete your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetCtx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey[600]!
                                : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[300]
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            customTheme?.preferenceButtonColor ?? theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete account',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom + 20),
            ],
          ),
        );
      },
    ) ?? false;
  }

  Future<void> _deleteUserDataAndAuth() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userId = user.uid;

    try {
      // 1. Delete Firestore data
      await _deleteFirestoreData(userId);
      
      // 2. Delete local data
      await _deleteLocalData(userId);
      
      // 3. Delete Firebase Auth user (this must be last)
      await user.delete();

      // Clear Google Sign-In cache to force account picker
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      // Force account selection by signing out completely
      await _auth.signOut();

      print('Account deletion completed successfully');
    } catch (e) {
      print('Error during account deletion: $e');
      rethrow;
    }
  }

  Future<void> _deleteFirestoreData(String userId) async {
    // Fault-tolerant: wrap each Firestore delete in its own try-catch
    bool userDocDeleted = false;
    // Delete user document
    try {
      await _firestore.collection('users').doc(userId).delete();
      userDocDeleted = true;
    } catch (e) {
      print('Error deleting user document: $e');
    }
    // Delete user behavior data
    try {
      await _firestore.collection('user_behavior').doc(userId).delete();
    } catch (e) {
      print('Error deleting user_behavior document: $e');
    }
    // Only try to delete subcollections if user doc still exists (was not deleted above)
    if (userDocDeleted) {
      final userRef = _firestore.collection('users').doc(userId);
      // Delete liked questions subcollection
      try {
        final likedSnapshot = await userRef.collection('liked_questions').get();
        for (final doc in likedSnapshot.docs) {
          try {
            await doc.reference.delete();
          } catch (e) {
            print('Error deleting liked_questions doc ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('Error getting liked_questions: $e');
      }
      // Delete user sessions subcollection
      try {
        final sessionsSnapshot = await userRef.collection('sessions').get();
        for (final doc in sessionsSnapshot.docs) {
          try {
            await doc.reference.delete();
          } catch (e) {
            print('Error deleting sessions doc ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('Error getting sessions: $e');
      }
    } else {
      print('User document already deleted; skipping subcollection deletions.');
    }
    print('Firestore data deleted for user: $userId');
  }

  Future<void> _deleteLocalData(String userId) async {
    try {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear Hive boxes
      final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
      
      for (final prefix in boxPrefixes) {
        // Clear default boxes
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
        
        // Clear user-specific boxes with proper typing
        try {
          final userBoxName = '${prefix}_$userId';
          if (Hive.isBoxOpen(userBoxName)) {
            if (prefix == 'swipeData') {
              final box = Hive.box(userBoxName); // Use dynamic for swipeData
              await box.clear();
              await box.close();
            } else {
              final box = Hive.box<Question>(userBoxName);
              await box.clear();
              await box.close();
            }
          }
          await Hive.deleteBoxFromDisk(userBoxName);
        } catch (e) {
          print('Error clearing user box ${prefix}_$userId: $e');
        }
        
        // Clear default pattern boxes
        for (final suffix in ['_default', '_temp']) {
          try {
            final boxName = '$prefix$suffix';
            if (Hive.isBoxOpen(boxName)) {
              final box = Hive.box(boxName);
              await box.clear();
              await box.close();
            }
            await Hive.deleteBoxFromDisk(boxName);
          } catch (e) {
            // Ignore if box doesn't exist
          }
        }
      }
      
      print('Local data deleted successfully');
    } catch (e) {
      print('Error deleting local data: $e');
      // Don't throw here - we still want to delete the auth account
    }
  }

  Future<void> _reauthWithPassword(BuildContext context, String? email) async {
    if (email == null) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'No email found for password authentication.',
      );
    }

    final pwd = await _showPasswordReauthSheet(context, email);

    if (pwd == null || pwd.isEmpty) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Password re-authentication cancelled.',
      );
    }

    final cred = EmailAuthProvider.credential(email: email, password: pwd);
    await _auth.currentUser!.reauthenticateWithCredential(cred);
  }

  Future<String?> _showPasswordReauthSheet(BuildContext context, String email) async {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final controller = TextEditingController();

    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[600]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Text(
                  'Confirm Identity',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 16),
                // Body
                Text(
                  'Please re-enter your password for\n$email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  style: const TextStyle(fontFamily: 'Runtime'),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(fontFamily: 'Runtime'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetCtx, null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetCtx, controller.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customTheme?.preferenceButtonColor ?? theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom + 20),
              ],
            ),
          ),
        );
      },
    );

    return result;
  }

  Future<void> _reauthWithGoogle(BuildContext context) async {
    try {
      final proceed = await _showProviderConfirmSheet(context, 'Google');
      if (proceed != true) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google re-authentication cancelled.',
        );
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(
                'Re-authenticating with Google...',
                style: TextStyle(fontFamily: 'Runtime'),
              ),
            ],
          ),
        ),
      );

      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google sign-in aborted.',
        );
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.currentUser!.reauthenticateWithCredential(credential);

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Google re-authentication successful');
    } catch (e) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (e is FirebaseAuthException) {
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'google-reauth-failed',
          message: 'Google re-authentication failed: $e',
        );
      }
    }
  }

  Future<bool> _showProviderConfirmSheet(BuildContext context, String providerLabel) async {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[600]
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Continue with $providerLabel',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To continue deleting your account, re‑authenticate with $providerLabel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetCtx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey[600]!
                                : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[300]
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customTheme?.preferenceButtonColor ?? theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom + 20),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _reauthWithApple(BuildContext context) async {
    try {
      final proceed = await _showProviderConfirmSheet(context, 'Apple');
      if (proceed != true) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Apple re-authentication cancelled.',
        );
      }
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(
                'Re-authenticating with Apple...',
                style: TextStyle(fontFamily: 'Runtime'),
              ),
            ],
          ),
        ),
      );

      final rawNonce = _randomNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Close loading dialog
      if (context != null && context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      await _auth.currentUser!.reauthenticateWithCredential(oauthCredential);
      print('Apple re-authentication successful');
    } catch (e) {
      // Close loading dialog if it's still open
      if (context != null && context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (e is FirebaseAuthException) {
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'apple-reauth-failed',
          message: 'Apple re-authentication failed: $e',
        );
      }
    }
  }

  // Helper methods
  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Runtime'),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _showDone(BuildContext context) async {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account deleted successfully. Goodbye!',
            style: TextStyle(fontFamily: 'Runtime'),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Wait longer and check context validity
    await Future.delayed(const Duration(milliseconds: 3000));

    // Navigate with better error handling
    if (context != null && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context != null && context.mounted) {
          context.go('/auth');
        }
      });
    }
  }

  String _randomNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}