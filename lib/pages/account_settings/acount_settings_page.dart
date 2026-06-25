import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../provider/theme_provider.dart';

class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({Key? key}) : super(key: key);

  // ── Reset password ──────────────────────────────────────────────────────────

  Future<void> _sendPasswordReset(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (!context.mounted) return;
      _showResult(
        context,
        success: true,
        message: 'Reset link sent to ${user.email}. Check your inbox.',
      );
    } catch (_) {
      if (!context.mounted) return;
      _showResult(
        context,
        success: false,
        message: 'Failed to send reset email. Please try again.',
      );
    }
  }

  // ── Change email ────────────────────────────────────────────────────────────

  void _showChangeEmail(BuildContext context) {
    final passwordController = TextEditingController();
    final newEmailController = TextEditingController();
    bool isSaving = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Change Email',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(32, 28, 17, 1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We\'ll send a verification link to your new address.',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 15, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _SheetField(
                  controller: newEmailController,
                  label: 'New Email',
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: passwordController,
                  label: 'Current Password',
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newEmail = newEmailController.text.trim();
                          final password = passwordController.text;
                          if (newEmail.isEmpty || !newEmail.contains('@')) {
                            setSheet(() => errorMessage =
                                'Please enter a valid email address.');
                            return;
                          }
                          if (password.isEmpty) {
                            setSheet(() => errorMessage =
                                'Please enter your current password.');
                            return;
                          }
                          setSheet(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          try {
                            final user =
                                FirebaseAuth.instance.currentUser!;
                            final cred = EmailAuthProvider.credential(
                              email: user.email!,
                              password: password,
                            );
                            await user.reauthenticateWithCredential(cred);
                            await user.verifyBeforeUpdateEmail(newEmail);
                            if (!ctx.mounted) return;
                            Navigator.of(sheetCtx).pop();
                            _showResult(
                              context,
                              success: true,
                              message:
                                  'Verification link sent to $newEmail. Click it to confirm the change.',
                            );
                          } on FirebaseAuthException catch (e) {
                            setSheet(() {
                              isSaving = false;
                              errorMessage =
                                  e.code == 'wrong-password'
                                      ? 'Incorrect password.'
                                      : e.code == 'email-already-in-use'
                                          ? 'That email is already in use.'
                                          : 'Something went wrong. Please try again.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(42, 63, 44, 1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Send Verification Link',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared snackbar helper ──────────────────────────────────────────────────

  void _showResult(BuildContext context,
      {required bool success, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Runtime', color: Colors.white),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final custom = theme.extension<CustomThemeExtension>();
    final fontColor = custom?.fontColor ?? Colors.black87;
    final accentColor =
        custom?.preferenceButtonColor ?? const Color.fromRGBO(42, 63, 44, 1);
    final cardColor = theme.cardColor;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final isEmailUser = user?.providerData
            .any((p) => p.providerId == 'password') ??
        false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: fontColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Account Settings',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current email display
              if (email.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 18,
                          color: fontColor.withOpacity(0.45)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 14,
                            color: fontColor.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action tiles
              _ActionTile(
                icon: Icons.lock_reset_rounded,
                title: 'Reset Password',
                subtitle: 'Send a reset link to your email',
                accentColor: accentColor,
                fontColor: fontColor,
                cardColor: cardColor,
                enabled: isEmailUser,
                onTap: () => _sendPasswordReset(context),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.alternate_email_rounded,
                title: 'Change Email',
                subtitle: 'Update the email address on your account',
                accentColor: accentColor,
                fontColor: fontColor,
                cardColor: cardColor,
                enabled: isEmailUser,
                onTap: () => _showChangeEmail(context),
              ),

              if (!isEmailUser) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: accentColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16,
                          color: accentColor.withOpacity(0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You signed in with Google or Apple. Password and email are managed by your provider.',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 12,
                            color: fontColor.withOpacity(0.55),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color fontColor;
  final Color cardColor;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.fontColor,
    required this.cardColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fontColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 12,
                        color: fontColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: fontColor.withOpacity(0.3), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet text field ───────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final bool autofocus;

  const _SheetField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofocus: autofocus,
      style: const TextStyle(fontFamily: 'Runtime', color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: 'Runtime', color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Color.fromRGBO(42, 63, 44, 1), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
