import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/theme_provider.dart';
import '../../provider/theme_provider.dart' show CustomThemeExtension;

class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Small palette helper so we can switch look by theme
  _Palette _paletteForTheme(BuildContext context) {
    final themeName = ref.watch(themeProvider).themeName; // 'catharsis_signature' | 'dark' | 'light'

    switch (themeName) {
      case 'dark':
        return _Palette(
          text: Colors.white,
          subText: Colors.white70,
          useImageBg: true,
          bgImageAsset: 'assets/images/dark_mode_background.png',
          showTextureOverlay: false,
        );
      case 'light':
        return _Palette(
          text: const Color(0xFF333333),
          subText: const Color(0xFF666666),
          useImageBg: true,
          bgImageAsset: 'assets/images/light_mode_background.png',
          showTextureOverlay: false,
        );
      default: // 'catharsis_signature'
        return _Palette(
          text: const Color.fromRGBO(32, 28, 17, 1),
          subText: const Color.fromRGBO(32, 28, 17, 1).withOpacity(0.8),
          useImageBg: false,
          gradientTop: const Color(0xFFFAF1E1),
          gradientBottom: const Color(0xFFFAF1E1),
          showTextureOverlay: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForTheme(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background – either gradient (signature) or themed image (dark/light)
          if (!palette.useImageBg)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.gradientTop!, palette.gradientBottom!.withOpacity(0.95)],
                ),
              ),
            )
          else
            Positioned.fill(
              child: Image.asset(
                palette.bgImageAsset!,
                fit: BoxFit.cover,
              ),
            ),

          if (palette.showTextureOverlay)
            Opacity(
              opacity: 0.4,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/background_texture.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildHowItWorksPage(palette),
                    _buildCategoriesPage(palette),
                  ],
                ),
              ),
              // Navigation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _currentPage > 0
                        ? TextButton(
                            onPressed: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            child: Text(
                              'Back',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: palette.text.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                          )
                        : const SizedBox(width: 60),
                    Row(
                      children: List.generate(
                        2,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? palette.text
                                : palette.text.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_currentPage < 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                      child: Text(
                        _currentPage < 1 ? 'Next' : 'Done',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: palette.text,
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
      ),
    );
  }

  Widget _buildWelcomePage(_Palette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/boat_illustration.png',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
            )
                .animate(onPlay: (c) => c.forward())
                .slideX(begin: 1.0, end: 0.0, duration: const Duration(seconds: 2), curve: Curves.easeInOut)
                .fadeIn(duration: const Duration(seconds: 1)),
            const SizedBox(height: 40),
            Text(
              'Welcome to\nCatharsis Cards',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: p.text,
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
                color: p.text,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksPage(_Palette p) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 40,
          vertical: isSmallScreen ? 24 : 40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: isSmallScreen ? 20 : 40),
            Text(
              'How It Works',
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: isSmallScreen ? 26 : 32,
                fontWeight: FontWeight.bold,
                color: p.text,
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 60),
            _featureItem(
              p: p,
              icon: Icons.swipe,
              title: 'Swipe Through Cards',
              description: 'Swipe left or right to explore thought-provoking questions',
            ),
            SizedBox(height: isSmallScreen ? 24 : 40),
            _featureItem(
              p: p,
              icon: Icons.favorite,
              title: 'Double Tap to Like',
              description: 'Save your favorite questions for later reflection',
            ),
            SizedBox(height: isSmallScreen ? 24 : 40),
            _featureItem(
              p: p,
              icon: Icons.category,
              title: 'Choose Categories',
              description: 'Filter questions by topics that resonate with you',
            ),
            SizedBox(height: isSmallScreen ? 24 : 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesPage(_Palette p) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    final categories = [
      {'name': 'Love & Intimacy', 'icon': 'assets/images/love_intimacy_icon.png'},
      {'name': 'Spirituality', 'icon': 'assets/images/spirituality_icon.png'},
      {'name': 'Society', 'icon': 'assets/images/society_icon.png'},
      {'name': 'Relationships', 'icon': 'assets/images/interactions_relationships_icon.png'},
      {'name': 'Personal Development', 'icon': 'assets/images/personal_development_icon.png'},
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 40,
          vertical: isSmallScreen ? 24 : 40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isSmallScreen)
              SizedBox(height: screenHeight * 0.08),
            Text(
              'Explore Categories',
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: isSmallScreen ? 26 : 32,
                fontWeight: FontWeight.bold,
                color: p.text,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 20),
            Text(
              'Questions tailored to your journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: isSmallScreen ? 14 : 16,
                color: p.subText,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 40),
            ...categories.map(
              (entry) => _categoryItem(
                p: p,
                name: entry['name']!,
                iconAsset: entry['icon']!,
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
          ],
        ),
      ),
    );
  }

  Widget _featureItem({required _Palette p, required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: Icon(icon, color: p.text.withOpacity(0.8), size: 30),
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
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 14,
                    color: p.subText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryItem({required _Palette p, required String name, required String iconAsset}) {
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
              iconAsset,
              width: 48,
              height: 48,
              color: p.text.withOpacity(0.8),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: p.text,
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

class _Palette {
  final Color text;
  final Color subText;
  final bool useImageBg;
  final String? bgImageAsset;
  final Color? gradientTop;
  final Color? gradientBottom;
  final bool showTextureOverlay;

  const _Palette({
    required this.text,
    required this.subText,
    required this.useImageBg,
    this.bgImageAsset,
    this.gradientTop,
    this.gradientBottom,
    required this.showTextureOverlay,
  });
}
