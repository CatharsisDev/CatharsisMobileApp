import 'package:catharsis_cards/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../provider/tutorial_state_provider.dart';
import '../../provider/user_profile_provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  static const List<String> _avatars = [
    'assets/images/avatar1.png',
    'assets/images/avatar2.png',
    'assets/images/avatar3.png',
    'assets/images/avatar4.png',
    'assets/images/avatar5.png',
    'assets/images/avatar6.png',
  ];
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Profile setup state
  String? _selectedAvatar;
  final TextEditingController _usernameController = TextEditingController();
  // Avatar carousel controller - increased viewportFraction for wider view
  late final PageController _avatarCarouselController;
  int _currentAvatarIndex = 0;
  // Image picker for custom avatar
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _customAvatarFile;
  Future<void> _pickCustomAvatar() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _customAvatarFile = picked;
        _selectedAvatar = picked.path;
      });
      // After adding the custom avatar, jump the carousel to focus it
      final newIndex = _avatars.length;
      _avatarCarouselController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Appearance carousel controller & state
  late final PageController _appearanceController;
  int _currentAppearancePage = 0;
  
  // Animation controller
  late AnimationController _animationController;
  late List<Animation<double>> _fadeAnimations;
  
  // Catharsis translations list (add this if you're using it)
  final List<String> _catharsisTranslations = [
    "Catharsis", "κάθαρσις", "カタルシス", "Catarse", "Katharsis"
  ];

  late final ProfanityFilter _profanityFilter;
  bool _hasProfanity = false;
  bool _hasInvalidChars = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 17),
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
    _profanityFilter = ProfanityFilter.filterAdditionally(['nazi', 'hitler']);
    _usernameController.addListener(() {
      setState(() {});
    });
    // Changed viewportFraction from 0.6 to 0.4 for narrower carousel
    _avatarCarouselController = PageController(viewportFraction: 0.4)
      ..addListener(() {
        final page = (_avatarCarouselController.page ?? 0).round();
        if (page != _currentAvatarIndex) {
          setState(() {
            _currentAvatarIndex = page;
            final avatarList = List<String>.from(_avatars);
            if (_customAvatarFile != null) {
              avatarList.add(_customAvatarFile!.path);
            }
            _selectedAvatar = avatarList[page];
          });
        }
      });
    _selectedAvatar = _avatars[0];
    // Appearance carousel setup
    _appearanceController = PageController(viewportFraction: 0.8)
      ..addListener(() {
        final page = (_appearanceController.page ?? 0).round();
        if (page != _currentAppearancePage) {
          setState(() {
            _currentAppearancePage = page;
          });
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _avatarCarouselController.dispose();
    _appearanceController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishTutorial() async {
    // Request notification permissions
    await NotificationService.init(); // This already handles permissions
    
    // Save profile data if provided
    if (_selectedAvatar != null || _usernameController.text.isNotEmpty) {
      await ref.read(userProfileProvider.notifier).updateProfile(
        avatar: _selectedAvatar,
        username: _usernameController.text.trim(),
      );
    }
    
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
          // Page 0: Email Verification
          _buildEmailVerificationPage(),

          // Page 1: Welcome Message
          _buildWelcomePage(),

          // Page 2: How it Works
          _buildHowItWorksPage(),

          // Page 3: Categories Introduction
          _buildCategoriesPage(),

          // Page 4: Appearance Theme Selection
          _buildAppearancePage(),

          // Page 5: Profile Setup
          _buildProfileSetupPage(),

          // Page 6: Get Started
          _buildGetStartedPage(),
        ],
      ),
    );
  }

  Widget _buildEmailVerificationPage() {
    // Matches the background and overlay of other slides, but only shows title, description, and a single "Continue" button.
    return Stack(
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
        // Content centered, no navigation or extra buttons
        Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verify Your Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(32, 28, 17, 1),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Please check your inbox for a verification email and click the link to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 18,
                    color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(32, 28, 17, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomePage() {
    return Stack(
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
        // Content with consistent navigation positioning
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/boat_illustration.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    )
                        .animate(
                          onPlay: (controller) => controller.forward(),
                        )
                        .slideX(
                          begin: 1.0,
                          end: 0.0,
                          duration: Duration(seconds: 2),
                          curve: Curves.easeInOut,
                        )
                        .fadeIn(duration: Duration(seconds: 1)),
                    const SizedBox(height: 40),
                    Text(
                      'Welcome to\nCatharsis Cards',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(32, 28, 17, 1),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your journey to emotional clarity\nand self-discovery begins here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(32, 28, 17, 1),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fixed position navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: _buildNavigationButtons(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHowItWorksPage() {
    return Stack(
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
        // Content with consistent navigation positioning
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'How It Works',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(32, 28, 17, 1),
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
            // Fixed position navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: _buildNavigationButtons(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoriesPage() {
    // Use explicit category data with icons
    final categories = [
      {'name': 'Love & Intimacy', 'icon': 'assets/images/love_intimacy_icon.png'},
      {'name': 'Spirituality', 'icon': 'assets/images/spirituality_icon.png'},
      {'name': 'Society', 'icon': 'assets/images/society_icon.png'},
      {'name': 'Relationships', 'icon': 'assets/images/interactions_relationships_icon.png'},
      {'name': 'Personal Development', 'icon': 'assets/images/personal_development_icon.png'},
    ];
    
    return Stack(
      children: [
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
        // Content with consistent navigation positioning
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Explore Categories',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(32, 28, 17, 1),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Questions tailored to your journey',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 16,
                        color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ...categories.asMap().entries.map((e) {
                      final idx = e.key;
                      final entry = e.value;
                      return _buildCategoryItem(entry)
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 200 * (idx + 1)))
                        .slideY(begin: 0.2);
                    }).toList(),
                  ],
                ),
              ),
            ),
            // Fixed position navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: _buildNavigationButtons(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileSetupPage() {
    final avatarList = List<String>.from(_avatars);
    if (_customAvatarFile != null) {
      avatarList.add(_customAvatarFile!.path);
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    // Background gradient
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
                    // Texture overlay
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
                    // Main content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Personalize Your Profile',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: const Color.fromRGBO(32, 28, 17, 1),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Text(
                                  'Choose your avatar and username',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 50),
                                // Avatar Selection
                                Text(
                                  'Choose Avatar',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color.fromRGBO(32, 28, 17, 1),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                // Added ShaderMask for edge blur effect
                                ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black,
                                        Colors.black,
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.1, 0.9, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: SizedBox(
                                    height: 100,
                                    child: PageView.builder(
                                      controller: _avatarCarouselController,
                                      itemCount: avatarList.length,
                                      itemBuilder: (context, index) {
                                        final imagePath = avatarList[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              _avatarCarouselController.animateToPage(
                                                index,
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            },
                                            child: _buildAvatarChoice(imagePath, index),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(avatarList.length, (i) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentAvatarIndex == i
                                            ? const Color.fromRGBO(42, 63, 44, 0.7)
                                            : Colors.grey,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickCustomAvatar,
                                    icon: const Icon(Icons.upload),
                                    label: const Text('Upload Avatar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromRGBO(32, 28, 17, 1),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const SizedBox(height: 40),
                                // Username Input
                                Text(
                                  'Username',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color.fromRGBO(32, 28, 17, 1),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _hasProfanity = _profanityFilter.hasProfanity(value);
                                        _hasInvalidChars = !RegExp(r'^[\p{L}\p{N}_]+$', unicode: true).hasMatch(value);
                                      });
                                    },
                                    controller: _usernameController,
                                    cursorColor: const Color.fromRGBO(42, 63, 44, 1),
                                    style: TextStyle(
                                      fontFamily: 'Runtime',
                                      fontSize: 16,
                                      color: const Color.fromRGBO(32, 28, 17, 1),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your username',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Runtime',
                                        color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    maxLength: 20,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                                if (_hasProfanity)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Username contains inappropriate language',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                if (_hasInvalidChars)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Username can only contain letters, numbers, and underscores',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                          child: _buildNavigationButtons(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGetStartedPage() {
    return Stack(
      children: [
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
        // Content centered properly
        Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    color: const Color(0xFF4A4A4A),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'You\'re All Set!',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(32, 28, 17, 1),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Begin your journey of\nself-discovery and reflection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 18,
                    color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 60),
                ElevatedButton(
                  onPressed: _finishTutorial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(32, 28, 17, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Start Exploring',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Ad Astra Per Aspera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearancePage() {
    // Local theme state for demo purposes only
    final selectedTheme = _currentAppearancePage == 0 ? 'catharsis_signature' 
                        : _currentAppearancePage == 1 ? 'dark' 
                        : 'light';
    
    // Define theme-specific colors for demo
    Color backgroundColor;
    Color textColor;
    Color secondaryTextColor;
    
    switch (selectedTheme) {
      case 'dark':
        backgroundColor = const Color(0xFF1A1A1A);
        textColor = Colors.white;
        secondaryTextColor = Colors.white70;
        break;
      case 'light':
        backgroundColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF333333);
        secondaryTextColor = const Color(0xFF666666);
        break;
      default: // catharsis_signature
        backgroundColor = const Color(0xFFFAF1E1);
        textColor = const Color.fromRGBO(32, 28, 17, 1);
        secondaryTextColor = const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.8);
    }

    return Stack(
      children: [
        // Dynamic background based on selected theme
        if (selectedTheme == 'catharsis_signature')
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
          )
        else
          Positioned.fill(
            child: Image.asset(
              selectedTheme == 'dark'
                  ? 'assets/images/dark_mode_background.png'
                  : 'assets/images/light_mode_background.png',
              fit: BoxFit.cover,
            ),
          ),
        // Texture overlay for default theme only
        if (selectedTheme == 'catharsis_signature')
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
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      child: const Text(
                        'Choose Your Theme',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 16,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                      child: const Text(
                        'Select the appearance that suits you best',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 350,
                      child: PageView.builder(
                        controller: _appearanceController,
                        itemCount: 3,
                        onPageChanged: (i) => setState(() => _currentAppearancePage = i),
                        itemBuilder: (ctx, i) {
                          final opts = [
                            {'title': 'Default', 'image': 'assets/images/default_theme_image.png', 'value': 'catharsis_signature'},
                            {'title': 'Dark', 'image': 'assets/images/dark_theme_image.png', 'value': 'dark'},
                            {'title': 'Light', 'image': 'assets/images/light_theme_image.png', 'value': 'light'},
                          ];
                          final o = opts[i];
                          final isSelected = i == _currentAppearancePage;
                          return GestureDetector(
                            onTap: () {
                              _appearanceController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    o['image']!,
                                    height: 250,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  child: Text(o['title']!),
                                ),
                                const SizedBox(height: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: textColor.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    color: isSelected 
                                        ? const Color.fromRGBO(42, 63, 44, 0.7) 
                                        : Colors.transparent,
                                  ),
                                  child: isSelected 
                                      ? const Icon(Icons.check, size: 16, color: Colors.white) 
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentAppearancePage == i
                                ? textColor
                                : textColor.withOpacity(0.3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 50),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                      child: const Text(
                        'This is just a preview - you can change themes later in settings',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Navigation buttons with dynamic colors
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: textColor.withOpacity(0.8),
                        fontSize: 16,
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      6,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? textColor
                              : textColor.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _nextPage,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarChoice(String imagePath, int index) {
    final isSelected = _selectedAvatar == imagePath;
    final isCurrent = _currentAvatarIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? const Color.fromRGBO(152, 117, 84, 1)
              : isCurrent
                  ? const Color.fromRGBO(152, 117, 84, 0.7)
                  : const Color(0xFF4A4A4A).withOpacity(0.3),
          width: isSelected ? 4 : isCurrent ? 2.5 : 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color.fromRGBO(42, 63, 44, 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
          ),
          child: ClipOval(
            child: Builder(
              builder: (_) {
                final localPath = imagePath.startsWith('file://')
                    ? imagePath.replaceFirst('file://', '')
                    : imagePath;
                final file = File(localPath);
                if (file.existsSync()) {
                  return Image.file(file, fit: BoxFit.cover);
                } else {
                  return Image.asset(imagePath, fit: BoxFit.cover);
                }
              },
            ),
          ),
        ),
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
            color: const Color(0xFF4A4A4A),
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
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(32, 28, 17, 1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 14,
                  color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.8),
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
        // Left side - Back button or spacer
        _currentPage > 0
            ? TextButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              )
            : const SizedBox(width: 60),

        // Center - Dots indicator
        Row(
          children: List.generate(
            7,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? const Color.fromRGBO(32, 28, 17, 1)
                    : const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.3),
              ),
            ),
          ),
        ),

        // Right side - Next button or spacer
        _currentPage < 6
            ? TextButton(
                onPressed: (_currentPage == 5 && (_usernameController.text.trim().isEmpty || _hasProfanity || _hasInvalidChars))
                    ? null
                    : _nextPage,
                child: Text(
                  'Next',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    color: const Color.fromRGBO(32, 28, 17, 1),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const SizedBox(width: 60),
      ],
    );
  }

  /// Builds a single category introduction item for the tutorial.
  Widget _buildCategoryItem(Map<String, String> entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Image.asset(
              entry['icon']!,
              width: 48,
              height: 48,
              color: const Color(0xFF4A4A4A),
            ),
            const SizedBox(width: 16),
            Flexible( 
              child: Text(
                entry['name']!,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color.fromRGBO(32, 28, 17, 1),
                ),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
    );
  }
}