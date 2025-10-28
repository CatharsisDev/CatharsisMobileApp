import 'dart:math';
import 'dart:io';
import 'package:catharsis_cards/questions_model.dart';
import 'package:catharsis_cards/services/user_behavior_service.dart';
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
    if (!context.mounted) return;
    
    final user = _auth.currentUser;
    if (user == null) {
      _showSnack(context, 'No user is currently signed in.');
      return;
    }

    final confirmed = await _showConfirmationDialog(context);
    if (!confirmed || !context.mounted) return;

    try {
      await _attemptDirectDeletion(context);
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _handleReauthenticationFlow(context, user);
      } else {
        _showSnack(context, 'Delete failed: ${e.message}');
      }
    } catch (e) {
      _showSnack(context, 'Delete failed: $e');
    }
  }

  Future<void> _attemptDirectDeletion(BuildContext context) async {
    _showLoadingDialog(context, 'Deleting account...');
    
    try {
      await _deleteUserDataAndAuth();
      _dismissDialog(context);
      await _showDone(context);
    } catch (e) {
      _dismissDialog(context);
      rethrow;
    }
  }

  Future<void> _handleReauthenticationFlow(BuildContext context, User user) async {
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
        _showSnack(context, 'Please sign in again to delete your account.');
        return;
      }

      // Retry deletion after successful re-authentication
      await _attemptDirectDeletion(context);
      
    } on FirebaseAuthException catch (e) {
      if (e.code != 'cancelled') {
        _showSnack(context, 'Delete failed: ${e.message}');
      }
    } catch (e) {
      _showSnack(context, 'Delete failed: $e');
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Runtime'),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      ),
    );
  }

  void _dismissDialog(BuildContext context) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    if (!context.mounted) return false;
    
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
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
                'This will permanently delete your account and all data. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
                        backgroundColor: Colors.red,
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
      // Explicitly reset user counters before deleting Firestore data
      await _resetUserCounters(userId);

      // 1. Delete Firestore data
      await _deleteFirestoreData(userId);
      
      // 2. Delete local data  
      await _deleteLocalData(userId);
      
      // 3. Delete Firebase Auth user (this must be last)
      await user.delete();
      
      // 4. Sign out completely
      await _auth.signOut();
      
      print('Account deletion completed successfully');
    } catch (e) {
      print('Error during account deletion: $e');
      rethrow;
    }
  }

  Future<void> _deleteFirestoreData(String userId) async {
    final tasks = <Future>[];

    // Delete main collections - use correct collection names
    tasks.add(_safeFirestoreDelete('users', userId));
    tasks.add(_safeFirestoreDelete('user_behaviors', userId)); // plural
    tasks.add(_safeFirestoreDelete('user_sessions', userId)); // from your service
    tasks.add(_safeFirestoreDelete('user_preferences', userId));

    // Delete subcollections
    tasks.add(_deleteSubcollection('users', userId, 'liked_questions'));
    tasks.add(_deleteSubcollection('user_behaviors', userId, 'views'));
    tasks.add(_deleteSubcollection('user_behaviors', userId, 'swipes'));
    tasks.add(_deleteSubcollection('user_sessions', userId, 'sessions'));

    await Future.wait(tasks);
    print('Firestore data deletion completed for user: $userId');
  }

  Future<void> _resetUserCounters(String userId) async {
    try {
      // Explicitly reset the seen cards counter before deletion
      await UserBehaviorService.resetSeenCardsCount();
      print('User counters reset for: $userId');
    } catch (e) {
      print('Error resetting user counters: $e');
    }
  }

  Future<void> _safeFirestoreDelete(String collection, String docId) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
      print('Deleted $collection/$docId');
    } catch (e) {
      print('Error deleting $collection/$docId: $e');
    }
  }

  Future<void> _deleteSubcollection(String parentCollection, String parentDoc, String subcollection) async {
    try {
      final snapshot = await _firestore
          .collection(parentCollection)
          .doc(parentDoc)
          .collection(subcollection)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        print('Deleted ${snapshot.docs.length} documents from $subcollection');
      }
    } catch (e) {
      print('Error deleting subcollection $subcollection: $e');
    }
  }

  Future<void> _deleteLocalData(String userId) async {
    try {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear Hive boxes
      await _clearHiveBoxes(userId);
      
      print('Local data deleted successfully');
    } catch (e) {
      print('Error deleting local data: $e');
    }
  }

  Future<void> _clearHiveBoxes(String userId) async {
    final boxPrefixes = ['likedQuestions', 'swipeData', 'cachedQuestions', 'seenQuestions'];
    
    for (final prefix in boxPrefixes) {
      await _clearBoxVariants(prefix, userId);
    }
  }

  Future<void> _clearBoxVariants(String prefix, String userId) async {
    final boxNames = [
      prefix,                    // Default box
      '${prefix}_$userId',       // User-specific box
      '${prefix}_default',       // Default pattern
      '${prefix}_temp',          // Temp pattern
    ];
    
    for (final boxName in boxNames) {
      await _clearSingleBox(boxName, prefix);
    }
  }

  Future<void> _clearSingleBox(String boxName, String prefix) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        final box = prefix == 'swipeData' 
            ? Hive.box(boxName) 
            : Hive.box<Question>(boxName);
        await box.clear();
        await box.close();
      }
      await Hive.deleteBoxFromDisk(boxName);
    } catch (e) {
      print('Error clearing box $boxName: $e');
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
    if (!context.mounted) return null;
    
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final controller = TextEditingController();

    return await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
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
                // Handle bar
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
                  'Confirm Identity',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter password for $email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 16,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'Runtime'),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(fontFamily: 'Runtime'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetCtx, null),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontFamily: 'Runtime'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetCtx, controller.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customTheme?.preferenceButtonColor ?? theme.primaryColor,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontFamily: 'Runtime',
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
  }

  Future<void> _reauthWithGoogle(BuildContext context) async {
    final proceed = await _showProviderConfirmSheet(context, 'Google');
    if (!proceed) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Google re-authentication cancelled.',
      );
    }

    _showLoadingDialog(context, 'Re-authenticating with Google...');

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut(); // Clear any cached session
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google sign-in cancelled.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.currentUser!.reauthenticateWithCredential(credential);
      _dismissDialog(context);
      print('Google re-authentication successful');
    } catch (e) {
      _dismissDialog(context);
      rethrow;
    }
  }

  Future<void> _reauthWithApple(BuildContext context) async {
    final proceed = await _showProviderConfirmSheet(context, 'Apple');
    if (!proceed) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Apple re-authentication cancelled.',
      );
    }

    _showLoadingDialog(context, 'Re-authenticating with Apple...');

    try {
      // Fresh nonce + state for this auth round
      final rawNonce = _randomNonce();
      final nonce = _sha256ofString(rawNonce);
      final state = _randomNonce(16);

      // Request Apple credentials.
      AuthorizationCredentialAppleID appleCredential;
      if (Platform.isIOS) {
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
          state: state,
        );
      } else {
        // Android (and others) use the web flow.
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
          state: state,
          webAuthenticationOptions: WebAuthenticationOptions(
            clientId: 'com.catharsis.cards.androidappleauth',
            redirectUri: Uri.parse('https://catharsiscards.firebaseapp.com/__/auth/handler'),
          ),
        );
      }

      // Build Firebase OAuth credential.
      // Important: include rawNonce and pass authorizationCode as accessToken for Android/web flows.
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,              // may be null on some Android flows
        accessToken: appleCredential.authorizationCode,      // use auth code here (works with Firebase)
        rawNonce: rawNonce,
      );

      await _auth.currentUser!.reauthenticateWithCredential(oauthCredential);

      _dismissDialog(context);
      print('Apple re-authentication successful');
    } on SignInWithAppleAuthorizationException catch (e) {
      _dismissDialog(context);
      // User cancelled from Apple sheet
      if (e.code == AuthorizationErrorCode.canceled) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Apple re-authentication cancelled by user.',
        );
      }
      print('Apple reauth error: $e');
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Apple did not return valid credentials. Please try again.',
      );
    } on FirebaseAuthException {
      _dismissDialog(context);
      rethrow;
    } catch (e) {
      _dismissDialog(context);
      print('Apple reauth unexpected error: $e');
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Apple re-authentication failed. Please try again.',
      );
    }
  }

  Future<bool> _showProviderConfirmSheet(BuildContext context, String providerLabel) async {
    if (!context.mounted) return false;
    
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
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
                'To delete your account, please re-authenticate with $providerLabel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
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
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'Runtime'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customTheme?.preferenceButtonColor ?? theme.primaryColor,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontFamily: 'Runtime',
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

  void _showSnack(BuildContext context, String msg) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Runtime'),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showDone(BuildContext context) async {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Account deleted successfully. Goodbye!',
          style: TextStyle(fontFamily: 'Runtime'),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 2500));

    if (context.mounted) {
      try {
        context.go('/login');
      } catch (_) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
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