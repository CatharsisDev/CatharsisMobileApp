import 'package:catharsis_cards/pages/welcome_screen/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../provider/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../provider/tutorial_state_provider.dart';
import 'email_verification_page.dart';

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

  // ── Forgot password ────────────────────────────────────────────────────────

  void _showForgotPassword() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSending = false;
    String? resultMessage;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
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
                    // Handle bar
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
                      'Reset Password',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(32, 28, 17, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email and we\'ll send you a link to reset your password.',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (resultMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? const Color(0xFF22C55E).withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSuccess
                                ? const Color(0xFF22C55E).withOpacity(0.4)
                                : Colors.red.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSuccess
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.error_outline_rounded,
                              size: 16,
                              color: isSuccess
                                  ? const Color(0xFF22C55E)
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                resultMessage!,
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  fontSize: 13,
                                  color: isSuccess
                                      ? const Color(0xFF22C55E)
                                      : Colors.red,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isSuccess) ...[
                      TextField(
                        controller: resetEmailController,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon:
                              Icon(Icons.email, color: Colors.grey[600]),
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
                        style: const TextStyle(
                          fontFamily: 'Runtime',
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isSending
                            ? null
                            : () async {
                                final email =
                                    resetEmailController.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setSheetState(() {
                                    resultMessage =
                                        'Please enter a valid email address.';
                                    isSuccess = false;
                                  });
                                  return;
                                }
                                setSheetState(() => isSending = true);
                                try {
                                  await FirebaseAuth.instance
                                      .sendPasswordResetEmail(email: email);
                                  setSheetState(() {
                                    isSending = false;
                                    isSuccess = true;
                                    resultMessage =
                                        'Reset link sent! Check your inbox (and spam folder).';
                                  });
                                } on FirebaseAuthException catch (e) {
                                  setSheetState(() {
                                    isSending = false;
                                    isSuccess = false;
                                    resultMessage = e.code == 'user-not-found'
                                        ? 'No account found with that email.'
                                        : 'Something went wrong. Please try again.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(42, 63, 44, 1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Send Reset Link',
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(42, 63, 44, 1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Back to Sign In',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
        // Send verification email
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
        // );
        // NOTE: Temporarily redirect straight to WelcomeScreen instead of email verification.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
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
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password';

    case 'email-already-in-use':
      return 'Email is already registered';

    case 'invalid-email':
      return 'Invalid email address';

    case 'weak-password':
    case 'invalid-password':
      return 'Password does not meet requirements';

    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';

    case 'network-request-failed':
      return 'Network error. Check your connection.';

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
            // Responsive SafeArea layout
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final isSmallPhone = height < 700;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          isSmallPhone ? 32 : 70,
                          20,
                          MediaQuery.of(context).padding.bottom + (isSmallPhone ? 16 : 20),
                        ),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/catharsis_word_only.png',
                              height: MediaQuery.of(context).size.height < 700
                                  ? MediaQuery.of(context).size.height * 0.08
                                  : MediaQuery.of(context).size.height * 0.1,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: MediaQuery.of(context).size.height < 700 ? 12 : 20),
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
                            SizedBox(height: MediaQuery.of(context).size.height < 700 ? 12 : 20),
                            Card(
                              elevation: 8,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(
                                  MediaQuery.of(context).size.height < 700 ? 16 : 20,
                                ),
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
                                            if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_]').hasMatch(value)) {
                                              return 'Password must contain a special character';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                      // Forgot password — login mode only
                                      if (_isLogin) ...[
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _showForgotPassword,
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 0, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Forgot password?',
                                              style: TextStyle(
                                                fontFamily: 'Runtime',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color.fromRGBO(42, 63, 44, 1),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
                                      SizedBox(height: MediaQuery.of(context).size.height < 700 ? 12 : 20),
                                      _isLoading
                                          ? const CircularProgressIndicator()
                                          : ElevatedButton(
                                              onPressed: _submitForm,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color.fromRGBO(42, 63, 44, 1),
                                                foregroundColor: Colors.white,
                                                minimumSize: Size(
                                                  double.infinity,
                                                  MediaQuery.of(context).size.height < 700 ? 46 : 50,
                                                ),
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
                            SizedBox(height: MediaQuery.of(context).size.height < 700 ? 12 : 20),
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
                            SizedBox(height: MediaQuery.of(context).size.height < 700 ? 12 : 20),
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
                            SizedBox(height: MediaQuery.of(context).size.height < 700 ? 12 : 16),
                            _SignInButton(
                              onPressed: () async {
                                try {
                                  final user = await ref.read(authServiceProvider).signInWithApple();
                                  if (user == null) {
                                    // User canceled — do nothing silently.
                                    return;
                                  }
                                  // Success: downstream navigation/logic will proceed automatically.
                                } on FirebaseAuthException catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message ?? 'Sign in failed.')),
                                  );
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Sign in failed.')),
                                  );
                                }
                              },
                              icon: FontAwesomeIcons.apple,
                              text: 'Sign in with Apple',
                              backgroundColor: Colors.black,
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ), // end SafeArea
          ],    // end Stack children
        ),      // end Stack
      ),
    );        // end Scaffold
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final dynamic icon;
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
          minimumSize: Size(
            double.infinity,
            MediaQuery.of(context).size.height < 700 ? 46 : 50,
          ),
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