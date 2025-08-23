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
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting account...'),
            ],
          ),
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
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      await _deleteUserDataAndAuth();
      Navigator.of(context).pop(); // Close loading dialog
      _showDone(context);
    } on FirebaseAuthException catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading dialog if open
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
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete your account and all associated data, including:'),
            SizedBox(height: 10),
            Text('• Your liked questions'),
            Text('• Your progress and preferences'),
            Text('• All personal data'),
            SizedBox(height: 15),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
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

    final controller = TextEditingController();
    final pwd = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Identity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please re-enter your password for $email'),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (pwd == null || pwd.isEmpty) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Password re-authentication cancelled.',
      );
    }

    final cred = EmailAuthProvider.credential(email: email, password: pwd);
    await _auth.currentUser!.reauthenticateWithCredential(cred);
  }

  // If you're having issues with google_sign_in, use this simpler version:

Future<void> _reauthWithGoogle(BuildContext context) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Re-authenticating with Google...'),
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

  Future<void> _reauthWithApple(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Re-authenticating with Apple...'),
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
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showDone(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deleted successfully. Goodbye!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
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