import 'dart:async';
import 'package:catharsis_cards/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../provider/tutorial_state_provider.dart';
import '../../provider/user_profile_provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/services.dart';


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
  
  static const Map<String, double> _avatarScaleTweak = {
    'assets/images/avatar3.png': 0.80,
  };

  static const Map<String, Alignment> _avatarAlignTweak = {
    'assets/images/avatar3.png': Alignment(0, -0.50),
  };
  
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String? _selectedAvatar;
  final TextEditingController _usernameController = TextEditingController();
  late final PageController _avatarCarouselController;
  int _currentAvatarIndex = 0;

  String? _avatarPath;
  static const String defaultAvatarPath = 'assets/images/avatar1.jpg';
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'custom_avatar.jpg';
        final newImage = await File(pickedFile.path).copy('${directory.path}/$fileName');

        if (_avatarPath != null && _avatarPath != defaultAvatarPath) {
          final oldFile = File(_avatarPath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        setState(() {
          _avatarPath = newImage.path;
          _selectedAvatar = newImage.path;
        });
      } catch (e) {
        print('Error copying image: $e');
      }
    }
  }

  late final PageController _appearanceController;
  int _currentAppearancePage = 0;

  late AnimationController _animationController;
  late List<Animation<double>> _fadeAnimations;
  Timer? _debounceTimer;

  final List<String> _catharsisTranslations = [
    "Catharsis", "κάθαρσις", "カタルシス", "Catarse", "Katharsis"
  ];

  late final ProfanityFilter _profanityFilter;
  bool _hasProfanity = false;
  bool _hasInvalidChars = false;
  bool _showUsernameError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animationController.forward();

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

    _profanityFilter = ProfanityFilter.filterAdditionally(['nazi', 'hitler']);
    _usernameController.addListener(() {
      setState(() {
        _showUsernameError = false;
      });
    });
    
    _avatarCarouselController = PageController(viewportFraction: 0.4)
      ..addListener(() {
        final page = (_avatarCarouselController.page ?? 0).round();
        if (page != _currentAvatarIndex) {
          setState(() {
            _currentAvatarIndex = page;
            final avatarList = List<String>.from(_avatars);
            if (_avatarPath != null) {
              avatarList.add(_avatarPath!);
            }
            _selectedAvatar = avatarList[page];
          });
        }
      });
    _selectedAvatar = _avatars[0];
    _avatarPath = null;
    
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

  double _responsiveFontSize(BuildContext context, double baseSize) {
    return baseSize * MediaQuery.of(context).size.width / 375;
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
  await NotificationService.init();

  if (_selectedAvatar != null || _usernameController.text.isNotEmpty) {
    File? avatarFile;
    
    // Convert avatar asset to File if selected
    if (_selectedAvatar != null) {
      try {
        final ByteData data = await rootBundle.load(_selectedAvatar!);
        final buffer = data.buffer;
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/tutorial_avatar.png');
        await tempFile.writeAsBytes(buffer.asUint8List());
        avatarFile = tempFile;
      } catch (e) {
        print('Error converting tutorial avatar: $e');
      }
    }
    
    await ref.read(userProfileProvider.notifier).updateProfile(
      avatarFile: avatarFile,
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
      backgroundColor: const Color(0xFFFAF1E1),
      resizeToAvoidBottomInset: true,
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) {
          // Prevent swiping forward from Profile Setup without valid username
          if (_currentPage == 4 &&
              index == 5 &&
              (_usernameController.text.trim().isEmpty ||
                  _hasProfanity ||
                  _hasInvalidChars)) {
            // Jump back and show message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController.jumpToPage(4);
              setState(() {
                _showUsernameError = true;
              });
            });
            return;
          }

          setState(() {
            _currentPage = index;
          });
        },
        children: [
          _buildWelcomePage(),
          _buildHowItWorksPage(),
          _buildCategoriesPage(),
          _buildAppearancePage(),
          _buildProfileSetupPage(),
          _buildGetStartedPage(),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
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
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 40,
                  right: 40,
                  top: MediaQuery.of(context).size.height * 0.1,
                  bottom: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/boat_illustration.png',
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: MediaQuery.of(context).size.height * 0.3,
                      fit: BoxFit.contain,
                    )
                        .animate(onPlay: (controller) => controller.forward())
                        .slideX(
                          begin: 1.0,
                          end: 0.0,
                          duration: const Duration(seconds: 2),
                          curve: Curves.easeInOut,
                        )
                        .fadeIn(duration: const Duration(seconds: 1)),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Welcome to\nCatharsis Cards',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: _responsiveFontSize(context, 36),
                          fontWeight: FontWeight.bold,
                          color: const Color.fromRGBO(32, 28, 17, 1),
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Your journey to emotional clarity\nand self-discovery begins here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: _responsiveFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(32, 28, 17, 1),
                            height: 1.5,
                          ),
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
    );
  }

  Widget _buildHowItWorksPage() {
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
                      description: 'Swipe left or right to explore thought-provoking questions. Left swipes will show you less of that category in the future',
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
    final categories = [
      {'name': 'Love & Intimacy', 'icon': 'assets/images/love_intimacy_icon.png'},
      {'name': 'Spirituality', 'icon': 'assets/images/spirituality_icon.png'},
      {'name': 'Society', 'icon': 'assets/images/society_icon.png'},
      {'name': 'Relationships', 'icon': 'assets/images/interactions_relationships_icon.png'},
      {'name': 'Personal Development', 'icon': 'assets/images/personal_development_icon.png'},
    ];

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

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
        Column(
          children: [
            // Header + list share vertical space; list scrolls naturally if needed.
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    isSmallScreen ? 24 : 48,
                    20,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Explore Categories',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(32, 28, 17, 1),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Questions tailored to your journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 16,
                            color: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.9),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      // Fill remaining space with the scrollable category list.
                      Expanded(
                        child: ListView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: categories.asMap().entries.map((e) {
                            final idx = e.key;
                            final entry = e.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildCategoryItem(entry)
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: 120 * (idx + 1)),
                                  )
                                  .slideY(begin: 0.15),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom navigation: use reasonable padding and respect safe area.
            SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: isSmallScreen ? 12 : 20,
                ),
                child: _buildNavigationButtons(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileSetupPage() {
    final avatarList = List<String>.from(_avatars);
    if (_avatarPath != null) {
      avatarList.add(_avatarPath!);
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

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
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 20 : 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Text(
                                      'Personalize Your Profile',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: isSmallScreen ? 22 : 26,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromRGBO(32, 28, 17, 1),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 16 : 30),
                                Text(
                                  'Choose your avatar and username',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color.fromRGBO(32, 28, 17, 1)
                                        .withOpacity(0.9),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 24 : 50),
                                Text(
                                  'Choose Avatar',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color.fromRGBO(32, 28, 17, 1),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 20 : 40),
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
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.upload, size: 18),
                                    label: const Text('Upload Avatar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color.fromRGBO(32, 28, 17, 1),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 16 : 24,
                                        vertical: isSmallScreen ? 10 : 12,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 20 : 40),
                                Text(
                                  'Username',
                                  style: TextStyle(
                                    fontFamily: 'Runtime',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color.fromRGBO(32, 28, 17, 1),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 16 : 24),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color.fromRGBO(32, 28, 17, 1)
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    onChanged: _checkText,
                                    controller: _usernameController,
                                    cursorColor:
                                        const Color.fromRGBO(42, 63, 44, 1),
                                    style: const TextStyle(
                                      fontFamily: 'Runtime',
                                      fontSize: 16,
                                      color:
                                          Color.fromRGBO(32, 28, 17, 1),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your username',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Runtime',
                                        color: const Color.fromRGBO(32, 28, 17, 1)
                                            .withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    maxLength: 20,
                                    buildCounter: (context,
                                            {required currentLength,
                                            required isFocused,
                                            maxLength}) =>
                                        null,
                                  ),
                                ),
                                if (_showUsernameError && _usernameController.text.trim().isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Please enter a username to continue',
                                      style: const TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                if (_hasProfanity)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Username contains inappropriate language',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 12,
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
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 20 : 40,
                            vertical: isSmallScreen ? 16 : 32,
                          ),
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
    final selectedTheme = _currentAppearancePage == 0
        ? 'catharsis_signature'
        : _currentAppearancePage == 1
            ? 'dark'
            : 'light';

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
      default:
        backgroundColor = const Color(0xFFFAF1E1);
        textColor = const Color.fromRGBO(32, 28, 17, 1);
        secondaryTextColor = const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.8);
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Stack(
      children: [
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: isSmallScreen ? screenHeight * 0.05 : screenHeight * 0.1,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isSmallScreen)
                        SizedBox(height: screenHeight * 0.05),
                      
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Choose Your Theme',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Select the appearance that suits you best',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 16,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      SizedBox(
                        height: screenHeight * 0.4,
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
                                      height: screenHeight * 0.28,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    o['title']!,
                                    style: TextStyle(
                                      fontFamily: 'Runtime',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
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
                      SizedBox(height: screenHeight * 0.02),
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
                      SizedBox(height: screenHeight * 0.03),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'This is just a preview - you can change themes later in settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                    child: Text(
                      'Back',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: textColor.withOpacity(0.8),
                        fontSize: 16,
                      ),
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
                    child: Text(
                      'Next',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
    final bool isCustom = _avatarPath != null && imagePath == _avatarPath;
    final double scale = isCustom ? 0.82 : (_avatarScaleTweak[imagePath] ?? 0.85);
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
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
          ),
          child: ClipOval(
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: scale,
                heightFactor: scale,
                child: _buildAvatar(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String imagePath, {BoxFit fit = BoxFit.cover}) {
    final bool isCustom = _avatarPath != null && imagePath == _avatarPath;
    final Alignment headBias = isCustom
        ? const Alignment(0, -0.15)
        : (_avatarAlignTweak[imagePath] ?? const Alignment(0, -0.55));

    if (isCustom) {
      return SizedBox.expand(
        child: Image.file(
          File(_avatarPath!),
          fit: fit,
          alignment: headBias,
        ),
      );
    } else if (imagePath.startsWith('assets/')) {
      return SizedBox.expand(
        child: Image.asset(
          imagePath,
          fit: fit,
          alignment: headBias,
        ),
      );
    } else {
      return SizedBox.expand(
        child: Image(
          image: const AssetImage('assets/images/default_avatar.jpeg'),
          fit: fit,
          alignment: headBias,
        ),
      );
    }
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required int delay,
  }) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Row(
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
                  style: const TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(32, 28, 17, 1),
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
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
                    ? const Color.fromRGBO(32, 28, 17, 1)
                    : const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.3),
              ),
            ),
          ),
        ),
        _currentPage < 5
            ? TextButton(
                onPressed: () {
                  if (_currentPage == 4 &&
                      (_usernameController.text.trim().isEmpty ||
                          _hasProfanity ||
                          _hasInvalidChars)) {
                    setState(() {
                      _showUsernameError = true;
                    });
                    return;
                  }
                  _nextPage();
                },
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

  Widget _buildCategoryItem(Map<String, String> entry) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Image.asset(
                entry['icon']!,
                width: 40,
                height: 45,
                color: const Color(0xFF4A4A4A),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  entry['name']!,
                  style: const TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color.fromRGBO(32, 28, 17, 1),
                  ),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkText(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _hasProfanity = _profanityFilter.hasProfanity(value);
        _hasInvalidChars =
            !RegExp(r'^[\p{L}\p{N}_]+$', unicode: true).hasMatch(value);
      });
    });
  }
}