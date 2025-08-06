import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../provider/theme_provider.dart';

class AccountSettingsPage extends ConsumerStatefulWidget {
  const AccountSettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _currentPasswordError;
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;

  // Password validation: at least 8 chars, one digit, one special char
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    final hasMinLength = value.length >= 8;
    final hasDigit = RegExp(r"\d").hasMatch(value);
    final hasSpecial = RegExp(r"[^A-Za-z0-9]").hasMatch(value);
    if (!hasMinLength) return 'Must be at least 8 characters.';
    if (!hasDigit) return 'Must contain at least one number.';
    if (!hasSpecial) return 'Must contain at least one special character.';
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _currentPasswordError = null;
      _emailError = null;
      _passwordError = null;
    });
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      // Update email / resend verification
      final newEmail = _emailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != user.email) {
        // Reauthenticate
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text.trim(),
        );
        await user.reauthenticateWithCredential(cred);
        // Update & send verification
        await user.updateEmail(newEmail);
        await user.reload();
        final updatedUser = FirebaseAuth.instance.currentUser!;
        await updatedUser.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification email sent to ${updatedUser.email}')),
        );
      } else if (newEmail == user.email && !user.emailVerified) {
        // Resend verification for same address
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification email resent to ${user.email}')),
        );
      }
      // Update password
      if (_passwordController.text.isNotEmpty) {
        await user.updatePassword(_passwordController.text.trim());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account updated successfully',
            style: TextStyle(fontFamily: 'Runtime'),
          ),
        ),
      );
      _currentPasswordController.clear();
      _emailController.clear();
      _passwordController.clear();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email' || e.code == 'email-already-in-use') {
        setState(() => _emailError = e.message);
      } else if (e.code == 'weak-password') {
        setState(() => _passwordError = e.message);
      } else if (e.code == 'wrong-password') {
        setState(() => _currentPasswordError = e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'Unexpected error',
              style: TextStyle(fontFamily: 'Runtime'),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: TextStyle(fontFamily: 'Runtime'),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Settings',
          style: TextStyle(fontFamily: 'Runtime'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Password
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                cursorColor: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(
                    fontFamily: 'Runtime',
                    fontWeight: FontWeight.bold,
                    color: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                  ),
                  errorStyle: TextStyle(fontFamily: 'Runtime'),
                  errorText: _currentPasswordError,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.extension<CustomThemeExtension>()?.buttonFontColor ?? theme.primaryColor,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.extension<CustomThemeExtension>()?.buttonFontColor ?? theme.primaryColor,
                    ),
                  ),
                ),
                style: TextStyle(fontFamily: 'Runtime'),
                validator: (value) {
                  if (_emailController.text.trim().isNotEmpty) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required to change email.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                cursorColor: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                decoration: InputDecoration(
                  labelText: 'New Email',
                  labelStyle: TextStyle(
                    fontFamily: 'Runtime',
                    fontWeight: FontWeight.bold,
                    color: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                  ),
                  floatingLabelStyle: TextStyle(
                    fontFamily: 'Runtime',
                    color: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                  ),
                  errorStyle: TextStyle(fontFamily: 'Runtime'),
                  errorText: _emailError,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.extension<CustomThemeExtension>()?.buttonFontColor ?? theme.primaryColor,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.extension<CustomThemeExtension>()?.buttonFontColor ?? theme.primaryColor,
                    ),
                  ),
                ),
                style: TextStyle(fontFamily: 'Runtime'),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final emailRegex = RegExp(r"^[^@]+@[^@]+\.[^@]+$");
                  if (!emailRegex.hasMatch(value)) return 'Invalid email format.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                cursorColor: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(
                    fontFamily: 'Runtime',
                    fontWeight: FontWeight.bold,
                    color: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                  ),
                  floatingLabelStyle: TextStyle(
                    fontFamily: 'Runtime',
                    color: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                  ),
                  errorStyle: TextStyle(fontFamily: 'Runtime'),
                  errorText: _passwordError,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.extension<CustomThemeExtension>()?.buttonFontColor ?? theme.primaryColor,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.extension<CustomThemeExtension>()?.buttonFontColor ?? theme.primaryColor,
                    ),
                  ),
                ),
                style: TextStyle(fontFamily: 'Runtime'),
                validator: _validatePassword,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.extension<CustomThemeExtension>()?.preferenceButtonColor,
                  foregroundColor: theme.extension<CustomThemeExtension>()?.buttonFontColor,
                ),
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          theme.extension<CustomThemeExtension>()?.buttonFontColor ?? Colors.white
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: TextStyle(fontFamily: 'Runtime',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        shadows: [
                Shadow(
                  color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.25),
                  offset: Offset(0, 1),
                  blurRadius: 15,
                ),
              ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
