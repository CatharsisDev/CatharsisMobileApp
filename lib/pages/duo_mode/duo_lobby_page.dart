import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../provider/theme_provider.dart';
import '../../provider/auth_provider.dart';
import '../../provider/duo_provider.dart';
import '../../provider/app_state_provider.dart';
import '../../services/duo_session_service.dart';

class DuoLobbyPage extends ConsumerStatefulWidget {
  const DuoLobbyPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DuoLobbyPage> createState() => _DuoLobbyPageState();
}

// Returns a visible accent color for duo mode, regardless of theme.
// Dark theme's primaryColor equals the background, so we use a purple accent instead.
Color _duoAccent(ThemeData t) {
  if (t.brightness == Brightness.dark) return const Color(0xFFBE89FF);
  return t.primaryColor;
}

class _DuoLobbyPageState extends ConsumerState<DuoLobbyPage> {
  final _codeController = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;
  String? _errorMessage;
  int _questionCount = 10; // how many cards to include in the session

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not logged in');

      // Pull questions from the current card session
      final cardState = ref.read(cardStateProvider);
      final questions = cardState.sessionQuestions.isNotEmpty
          ? cardState.sessionQuestions
          : cardState.allQuestions;

      if (questions.isEmpty) throw Exception('No cards available. Please wait and try again.');

      final displayName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email?.split('@').first ?? 'Host';

      final code = await DuoSessionService.createSession(
        hostUid: user.uid,
        hostName: displayName,
        questions: questions.take(_questionCount).toList(),
      );

      ref.read(duoSessionCodeProvider.notifier).state = code;
      ref.read(duoIsHostProvider.notifier).state = true;

      if (mounted) context.push('/duo/session/$code');
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-character code.');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not logged in');

      final displayName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email?.split('@').first ?? 'Guest';

      await DuoSessionService.joinSession(
        code: code,
        guestUid: user.uid,
        guestName: displayName,
      );

      ref.read(duoSessionCodeProvider.notifier).state = code;
      ref.read(duoIsHostProvider.notifier).state = false;

      if (mounted) context.push('/duo/session/$code');
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final customTheme = appTheme.extension<CustomThemeExtension>();
    final fontColor = customTheme?.fontColor ?? appTheme.textTheme.bodyMedium?.color ?? Colors.black87;
    final accentColor = _duoAccent(appTheme);
    const errorColor = Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: fontColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Duo Mode',
          style: TextStyle(
            color: fontColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Header illustration
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.people_rounded, size: 52, color: accentColor),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Swipe Together',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fontColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Explore deep questions with a partner. See where you match — and where you differ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fontColor.withOpacity(0.6),
                  height: 1.5,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 32),

              // ── Start Session ────────────────────────────────────────────
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: accentColor, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Start a Session',
                          style: TextStyle(
                            color: fontColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a session and share the code with your partner.',
                      style: TextStyle(color: fontColor.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // ── Number of questions picker ──────────────────────────
                    Row(
                      children: [
                        Text(
                          'Questions:',
                          style: TextStyle(
                            color: fontColor.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [5, 10, 15, 20].map((n) {
                              final selected = _questionCount == n;
                              return GestureDetector(
                                onTap: () => setState(() => _questionCount = n),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 48,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? accentColor
                                        : accentColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? accentColor
                                          : accentColor.withOpacity(0.25),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$n',
                                      style: TextStyle(
                                        color: selected ? Colors.white : accentColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _createSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Start with $_questionCount questions',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Join Session ─────────────────────────────────────────────
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.login_rounded, color: accentColor, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Join a Session',
                          style: TextStyle(
                            color: fontColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-character code from your partner.',
                      style: TextStyle(color: fontColor.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: TextStyle(
                        color: fontColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'XXXXXX',
                        hintStyle: TextStyle(
                          color: fontColor.withOpacity(0.25),
                          letterSpacing: 6,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                        filled: true,
                        fillColor: appTheme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fontColor.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fontColor.withOpacity(0.2)),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      ],
                      onSubmitted: (_) => _joinSession(),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _isJoining ? null : _joinSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Join Session',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: errorColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: errorColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: errorColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
