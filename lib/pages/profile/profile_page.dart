import 'package:catharsis_cards/pages/main_settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../provider/auth_provider.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/theme_provider.dart';
import '../../question_categories.dart';
import '../main_settings/settings_page.dart';
import 'package:go_router/go_router.dart';

class ProfilePageWidget extends ConsumerStatefulWidget {
  const ProfilePageWidget({super.key});

  @override
  ConsumerState<ProfilePageWidget> createState() => _ProfilePageWidgetState();
}

class _ProfilePageWidgetState extends ConsumerState<ProfilePageWidget> {

  void _showCategoryFilterDialog() {
    final cardState = ref.read(cardStateProvider);
    Set<String> tempSelected = cardState.selectedCategories
        .map((cat) => cat.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toSet();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final displayCats = QuestionCategories.getAllCategories();

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF1E1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Categories',
                            style: GoogleFonts.raleway(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => tempSelected.clear()),
                            child: Text(
                              'Clear All',
                              style: GoogleFonts.raleway(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: displayCats.map((display) {
                          final key = QuestionCategories.normalizeCategory(display);
                          final isSelected = tempSelected.contains(key);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      tempSelected.remove(key);
                                    } else {
                                      tempSelected.add(key);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? const Color.fromRGBO(152, 117, 84, 0.1) 
                                        : const Color(0xFFFAF1E1), 
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF8B4F4F), width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          display,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.raleway(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              ref.read(cardStateProvider.notifier).updateSelectedCategories(tempSelected);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(42, 63, 44, 1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Apply',
                              style: GoogleFonts.raleway(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final authService = ref.read(authServiceProvider);
    final cardState = ref.watch(cardStateProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Opacity(
            opacity: 0.5,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background_texture.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Icon(
                          Icons.arrow_back_ios,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: Colors.black87,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showCategoryFilterDialog,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF987554).withOpacity(0.1),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/preferences_icon.png',
                              width: 24,
                              height: 24,
                              color: const Color(0xFF987554),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => SettingsMenuPage(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.ease;
                                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF987554).withOpacity(0.1),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/settings_icon.png',
                              width: 24,
                              height: 24,
                              color: const Color(0xFF987554),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Profile Content
                Expanded(
                  child: Stack(
                    children: [
                      // White background that extends to bottom
                      Positioned(
                        top: 70, // Position below where avatar starts
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 253, 240, 1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                        ),
                      ),
                      // Original content
                      SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            
                            // User Avatar with white border to create notch effect
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color.fromRGBO(255, 253, 240, 1),
                                border: Border.all(color: Colors.white, width: 8),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF987554),
                                ),
                                child: Center(
                                  child: authState.when(
                                    data: (user) => Text(
                                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    loading: () => CircularProgressIndicator(color: Colors.white),
                                    error: (_, __) => Icon(Icons.error, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // User Name (using email for now)
                            authState.when(
                              data: (user) => Text(
                                user?.email?.split('@')[0] ?? 'User',
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  color: Colors.black87,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              loading: () => Text('Loading...'),
                              error: (_, __) => Text('Error'),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // User Email
                            authState.when(
                              data: (user) => Text(
                                user?.email ?? 'No email',
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  color: const Color.fromRGBO(32, 28, 17, 1),
                                  fontSize: 16,
                                ),
                              ),
                              loading: () => Text('Loading...'),
                              error: (_, __) => Text('Error'),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Statistics Cards
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatCard(
                                  '${cardState.likedQuestions.length}',
                                  'Liked Cards',
                                  Icons.favorite,
                                  Colors.red,
                                ),
                                const SizedBox(width: 16),
                                _buildStatCard(
                                  '${cardState.seenQuestions.length}',
                                  'Cards Seen',
                                  Icons.remove_red_eye,
                                  Colors.blue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom Navigation removed from here
              ],
            ),
          ),
          // Bottom Navigation moved here as a direct child of Stack
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color.fromRGBO(255, 253, 240, 1),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/home_icon.png',
                            width: 24,
                            height: 24,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Home',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/profile_icon.png',
                            width: 24,
                            height: 24,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profile',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String title, IconData icon, Color color) {
    return Container(
      width: 165,
      height: 190,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: AssetImage("assets/images/background_texture.png"),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Runtime',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Runtime',
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}