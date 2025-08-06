import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../provider/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../provider/tutorial_state_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      if (_isLogin) {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        // Reset tutorial state BEFORE registering
        print('Resetting tutorial state before registration');
        await ref.read(tutorialProvider.notifier).resetTutorial();
        
        // Force the tutorial provider to reinitialize immediately
        ref.invalidate(tutorialProvider);
        
        // Small delay to ensure state is updated
        await Future.delayed(Duration(milliseconds: 100));
        
        // Now register the user
        await authService.registerWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        print('New user registered - router should redirect to welcome');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
      case 'invalid-password':
        return 'Password does not meet requirements (min 8 chars, uppercase, lowercase, number & special char)';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);

    return Theme(
      // Override theme to ensure consistent styling
      data: ThemeData.light().copyWith(
        primaryColor: Color.fromRGBO(42, 63, 44, 1),
        colorScheme: ColorScheme.light(
          primary: Color.fromRGBO(42, 63, 44, 1),
        ),
      ),
      child: Scaffold(
        backgroundColor: Color(0xFFFAF1E1),
        body: Stack(
          children: [
            // Cream gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFAF1E1),
                    const Color(0xFFFAF1E1).withOpacity(0.95),
                  ],
                ),
              ),
            ),
            // Texture overlay at 40% opacity
            Opacity(
              opacity: 0.4,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/background_texture.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Existing SafeArea + ListView
            SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                children: [
                  Image.asset(
                    'assets/images/catharsis_word_only.png',
                    height: MediaQuery.of(context).size.height * 0.20,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      _isLogin ? 'Welcome Back' : 'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(32, 28, 17, 1),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Card(
                    elevation: 8,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.email, color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromRGBO(42, 63, 44, 1), width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromRGBO(42, 63, 44, 1), width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (!_isLogin) {
                                  // Minimum length
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  // Uppercase letter
                                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                    return 'Password must contain an uppercase letter';
                                  }
                                  // Lowercase letter
                                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                                    return 'Password must contain a lowercase letter';
                                  }
                                  // Numeric digit
                                  if (!RegExp(r'\d').hasMatch(value)) {
                                    return 'Password must contain a number';
                                  }
                                  // Special character
                                  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
                                    return 'Password must contain a special character';
                                  }
                                }
                                return null;
                              },
                            ),
                            if (_errorMessage != null) ...[
                              SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            SizedBox(height: 20),
                            _isLoading
                                ? CircularProgressIndicator(
                                    color: Color.fromRGBO(42, 63, 44, 1),
                                  )
                                : ElevatedButton(
                                    onPressed: _submitForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color.fromRGBO(42, 63, 44, 1),
                                      foregroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      _isLogin ? 'Sign In' : 'Register',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _errorMessage = null;
                                });
                              },
                              child: Text(
                                _isLogin
                                    ? "Don't have an account? Register"
                                    : "Already have an account? Sign In",
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromRGBO(42, 63, 44, 1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Or continue with',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(32, 28, 17, 1),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _SignInButton(
                    onPressed: () async {
                      await authService.signInWithGoogle();
                      // Router will handle redirecting new users to welcome screen
                    },
                    icon: FontAwesomeIcons.google,
                    text: 'Sign in with Google',
                    backgroundColor: Colors.white,
                    textColor: Colors.black87,
                  ),
                  SizedBox(height: 16),
                  _SignInButton(
                    onPressed: () async {
                      await authService.signInWithApple();
                      // Router will handle redirecting new users to welcome screen
                    },
                    icon: FontAwesomeIcons.apple,
                    text: 'Sign in with Apple',
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),  // end SafeArea
          ],    // end Stack children
        ),      // end Stack
      ),
    );        // end Scaffold
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _SignInButton({
    required this.onPressed,
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          minimumSize: Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: backgroundColor == Colors.white ? Colors.grey[300]! : Colors.transparent,
            ),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: textColor, size: 20),
            SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Runtime',
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}