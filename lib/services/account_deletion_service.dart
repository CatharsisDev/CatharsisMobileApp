import 'dart:math';
import 'dart:io';
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
      _showSnack(context, 'No user is currently signed in.');
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
          actions: [
            // Keep layout stable; message styled below Text widget
          ],
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
      );

      // Try delete directly first
      await _deleteUserDataAndAuth();
      Navigator.of(context).pop(); // Close loading dialog
      _showDone(context);
      return;
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      
      if (e.code != 'requires-recent-login') {
        _showSnack(context, 'Delete failed: ${e.message}');
        return;
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showSnack(context, 'Delete failed: $e');
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
        // Anonymous users typically don't require reauth
        print('Anonymous user - proceeding without reauth');
      } else {
        _showSnack(context, 'Please sign in again to delete your account.');
        return;
      }

      // Show loading dialog again
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

      await _deleteUserDataAndAuth();
      Navigator.of(context).pop(); // Close loading dialog
      _showDone(context);
    } on FirebaseAuthException catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // If the user cancelled any re-auth step, do not show an error.
      if (e.code == 'cancelled') {
        // Optional: you can show a subtle info toast here instead of an error,
        // or simply do nothing to silently cancel the deletion flow.
        return;
      }

      _showSnack(context, 'Delete failed: ${e.message}');
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading dialog if open
      }
      _showSnack(context, 'Delete failed: $e');
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
      
      print('Account deletion completed successfully');
    } catch (e) {
      print('Error during account deletion: $e');
      rethrow;
    }
  }

  Future<void> _deleteFirestoreData(String userId) async {
    try {
      // Delete user document
      await _firestore.collection('users').doc(userId).delete();
      
      // Delete user behavior data
      await _firestore.collection('user_behavior').doc(userId).delete();
      
      // Delete any subcollections if they exist
      final userRef = _firestore.collection('users').doc(userId);
      
      // Delete liked questions subcollection
      final likedSnapshot = await userRef.collection('liked_questions').get();
      for (final doc in likedSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete user sessions subcollection
      final sessionsSnapshot = await userRef.collection('sessions').get();
      for (final doc in sessionsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      print('Firestore data deleted for user: $userId');
    } catch (e) {
      print('Error deleting Firestore data: $e');
      // Don't throw here - we still want to delete the auth account
    }
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
        
        // Clear user-specific boxes
        try {
          final userBoxName = '${prefix}_$userId';
          if (Hive.isBoxOpen(userBoxName)) {
            final box = Hive.box(userBoxName);
            await box.clear();
            await box.close();
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

  // If you're having issues with google_sign_in, use this simpler version:

  Future<void> _reauthWithGoogle(BuildContext context) async {
    try {
      final proceed = await _showProviderConfirmSheet(context, 'Google');
      if (proceed != true) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google re-authentication cancelled.',
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
                'Re-authenticating with Google...',
                style: TextStyle(fontFamily: 'Runtime'),
              ),
            ],
          ),
        ),
      );

      // Use Firebase Auth's built-in Google provider
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Add scopes if needed
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // Re-authenticate with the provider
      await _auth.currentUser!.reauthenticateWithProvider(googleProvider);

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Google re-authentication successful');
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
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
      if (Navigator.of(context).canPop()) {
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
      if (Navigator.of(context).canPop()) {
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

  void _showDone(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Account deleted successfully. Goodbye!',
          style: TextStyle(fontFamily: 'Runtime'),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // After a short delay, navigate back to the auth/sign-up flow
    Future.delayed(const Duration(milliseconds: 900), () {
      // Prefer GoRouter if available
      try {
        // Adjust this primary route to your actual auth route if different
        context.go('/auth');
        return;
      } catch (_) {
        // Fallbacks for projects not using GoRouter or with different route names
        final navigator = Navigator.of(context, rootNavigator: true);

        // Try common named routes
        for (final route in const ['/auth', '/login', '/signup', '/onboarding']) {
          try {
            navigator.pushNamedAndRemoveUntil(route, (r) => false);
            return;
          } catch (_) {
            // Try next candidate
          }
        }

        // Last resort: clear to first route (e.g., splash) if no named routes matched
        navigator.popUntil((r) => r.isFirst);
      }
    });
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