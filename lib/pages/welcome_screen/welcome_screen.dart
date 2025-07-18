import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../provider/tutorial_state_provider.dart';
import '../../index.dart'; 

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late List<Animation<double>> _fadeAnimations;
  
  // Different translations of "Catharsis"
  final List<Map<String, String>> _catharsisTranslations = [
    {'text': 'Catharsis', 'language': 'English'},
    {'text': 'Catarsis', 'language': 'Spanish'},
    {'text': 'Catharsis', 'language': 'French'},
    {'text': 'Katharsis', 'language': 'German'},
    {'text': 'Catarsi', 'language': 'Italian'},
    {'text': 'Κάθαρσις', 'language': 'Greek'},
    {'text': 'カタルシス', 'language': 'Japanese'},
    {'text': '净化', 'language': 'Chinese'},
    {'text': 'Катарсис', 'language': 'Russian'},
    {'text': 'تطهير', 'language': 'Arabic'},
    {'text': '宣泄', 'language': 'Catonese'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 17), // Reduced from 20 to 15 for faster cycles
      vsync: this,
    );
    
    // Create staggered animations for each translation
    _fadeAnimations = List.generate(
      _catharsisTranslations.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index / _catharsisTranslations.length,
            (index + 1) / _catharsisTranslations.length,
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );
    
    // Start the animation and make it repeat
    _animationController.forward();
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishTutorial() async {
    await ref.read(tutorialProvider.notifier).setTutorialSeen();
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          // Page 1: Animated Catharsis
          // _buildAnimatedCatharsisPage(), // Remove this line
          
          // Page 2: Welcome Message
          _buildWelcomePage(),
          
          // Page 3: How it Works
          _buildHowItWorksPage(),
          
          // Page 4: Categories Introduction
          _buildCategoriesPage(),
          
          // Page 5: Get Started
          _buildGetStartedPage(),
        ],
      ),
    );
  }

  Widget _buildAnimatedCatharsisPage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.black.withOpacity(0.95),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated translations
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(
                _catharsisTranslations.length,
                (index) => AnimatedBuilder(
                  animation: _fadeAnimations[index],
                  builder: (context, child) {
                    return Opacity(
                      opacity: index == _catharsisTranslations.length - 1
                          ? _fadeAnimations[index].value
                          : (_fadeAnimations[index].value - 
                             (index < _catharsisTranslations.length - 1 
                                ? _fadeAnimations[index + 1].value 
                                : 0)).clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _catharsisTranslations[index]['text']!,
                            style: GoogleFonts.raleway(
                              fontSize: 48,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Skip/Continue button
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: _nextPage,
                child: Text(
                  'Continue',
                  style: GoogleFonts.raleway(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ).animate(
                onPlay: (controller) => controller.repeat(),
              ).shimmer(
                duration: const Duration(seconds: 2),
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D3648),
            const Color(0xFF1E2432),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 80,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(height: 40),
                Text(
                  'Welcome to\nCatharsis Cards',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.raleway(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your journey to emotional clarity\nand self-discovery begins here',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.raleway(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildHowItWorksPage() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                const Color(0xFFD0A4B4),
                const Color(0xFFB08095),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How It Works',
                  style: GoogleFonts.raleway(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 60),
                _buildFeatureItem(
                  icon: Icons.swipe,
                  title: 'Swipe Through Cards',
                  description: 'Swipe left or right to explore thought-provoking questions',
                  delay: 200,
                ),
                const SizedBox(height: 40),
                _buildFeatureItem(
                  icon: Icons.favorite,
                  title: 'Double Tap to Like',
                  description: 'Save your favorite questions for later reflection',
                  delay: 400,
                ),
                const SizedBox(height: 40),
                _buildFeatureItem(
                  icon: Icons.category,
                  title: 'Choose Categories',
                  description: 'Filter questions by topics that resonate with you',
                  delay: 600,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: _buildNavigationButtons(),
        ),
      ],
    );
  }

  Widget _buildCategoriesPage() {
    // Update the categories list to use asset paths
    final categories = [
      {'name': 'Love & Intimacy', 'icon': 'assets/images/love_intimacy_icon.png'},
      {'name': 'Spirituality', 'icon': 'assets/images/spirituality_icon.png'},
      {'name': 'Society', 'icon': 'assets/images/society_icon.png'},
      {'name': 'Relationships', 'icon': 'assets/images/interactions_relationships_icon.png'},
      {'name': 'Personal Development', 'icon': 'assets/images/personal_development_icon.png'},
    ];

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            const Color(0xFF8CC6FF),
            const Color(0xFF6BA3DB),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Explore Categories',
                  style: GoogleFonts.raleway(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 20),
                Text(
                  'Questions tailored to your journey',
                  style: GoogleFonts.raleway(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 40),
                ...categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            category['icon'] as String,
                            width: 64,
                            height: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            category['name'] as String,
                            style: GoogleFonts.raleway(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ).animate().slideX(
                      begin: 0.2,
                      delay: Duration(milliseconds: 200 + (index * 100)),
                      duration: 600.ms,
                    ).fadeIn(),
                  );
                }).toList(),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildGetStartedPage() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2D3648),
            const Color(0xFF1E2432),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.check,
              size: 60,
              color: Colors.white,
            ),
          ).animate().scale(duration: 600.ms),
          const SizedBox(height: 40),
          Text(
            'You\'re All Set!',
            style: GoogleFonts.raleway(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(duration: 800.ms),
          const SizedBox(height: 20),
          Text(
            'Begin your journey of\nself-discovery and reflection',
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: _finishTutorial,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2D3648),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Start Exploring',
              style: GoogleFonts.raleway(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().fadeIn(delay: 800.ms).scale(),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required int delay,
  }) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.raleway(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.raleway(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideX(begin: 0.1);
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentPage > 0)
          TextButton(
            onPressed: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Text(
              'Back',
              style: GoogleFonts.raleway(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          )
        else
          const SizedBox(width: 60),
        Row(
          children: List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ),
        if (_currentPage < 3)
          TextButton(
            onPressed: _nextPage,
            child: Text(
              'Next',
              style: GoogleFonts.raleway(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          const SizedBox(width: 60),
      ],
    );
  }
}