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
    // Normalize the selected categories for comparison
    Set<String> tempSelected = cardState.selectedCategories
        .map((cat) => cat.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toSet();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Filter Categories',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: QuestionCategories.getAllCategories().map((category) {
                    // Normalize the category for comparison
                    final normalizedCategory = category.replaceAll(RegExp(r'\s+'), ' ').trim();
                    
                    return CheckboxListTile(
                      title: Text(
                        category,
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                        ),
                      ),
                      value: tempSelected.contains(normalizedCategory),
                      activeColor: category.toCategoryColor(),
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value ?? false) {
                            tempSelected.add(normalizedCategory);
                          } else {
                            tempSelected.remove(normalizedCategory);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      tempSelected.clear();
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update the global state with selected categories
                    ref.read(cardStateProvider.notifier).updateSelectedCategories(tempSelected);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tempSelected.isEmpty 
                            ? 'Showing all categories' 
                            : 'Filters applied: ${tempSelected.length} categories selected',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD0A4B4),
                  ),
                  child: Text('Apply'),
                ),
              ],
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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ref.watch(themeProvider).themeName == 'dark'
                    ? [Color(0xFF1E1E1E), Color(0xFF121212)]
                    : ref.watch(themeProvider).themeName == 'light'
                        ? [Color.fromARGB(235, 201, 197, 197), Color.fromARGB(255, 255, 255, 255)]
                        : [Color.fromARGB(235, 208, 164, 180), Color.fromARGB(255, 140, 198, 255)],
                stops: [0.0, 1.0],
                begin: AlignmentDirectional(0.6, -0.34),
                end: AlignmentDirectional(-1.0, 0.34),
              ),
            ),
          ),
          // Background with HomePage texture
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
            child: Opacity(
              opacity: 0.3,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/background_texture.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          // SafeArea container with original page content
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Stack(
                            children: [
                              Transform.translate(
                                offset: Offset(-12, 0),
                                child: GestureDetector(
                                  onTap: _showCategoryFilterDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF987554).withOpacity(0.1),
                                    ),
                                    child: Image.asset(
                                      'assets/images/preferences_icon.png',
                                      width: 24,
                                      height: 24,
                                    ),
                                  ),
                                ),
                              ),
                              if (cardState.selectedCategories.isNotEmpty)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${cardState.selectedCategories.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF987554).withOpacity(0.1),
                              ),
                              child: Image.asset(
                                'assets/images/settings_icon.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Profile Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // User Avatar
                        authState.when(
                          data: (user) => CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: Text(
                              user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFD0A4B4),
                              ),
                            ),
                          ),
                          loading: () => CircularProgressIndicator(),
                          error: (_, __) => Icon(Icons.error),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // User Email
                        authState.when(
                          data: (user) => Text(
                            user?.email ?? 'No email',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: const Color.fromARGB(255, 0, 0, 0),
                              fontSize: 18,
                              letterSpacing: 1.3
                            ),
                          ),
                          loading: () => Text('Loading...'),
                          error: (_, __) => Text('Error'),
                        ),
                        
                        SizedBox(height: 40),
                        
                        // Statistics Cards
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard(
                              'Liked Cards',
                              '${cardState.likedQuestions.length}',
                              Icons.favorite,
                              Colors.red,
                            ),
                            _buildStatCard(
                              'Cards Seen',
                              '${cardState.seenQuestions.length}',
                              Icons.visibility,
                              Colors.blue,
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 20),
                        
                        // Active Filters Info
                        if (cardState.selectedCategories.isNotEmpty)
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Filters',
                                    style: GoogleFonts.raleway(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: cardState.selectedCategories.map((category) {
                                      // Display the normalized category name
                                      final displayCategory = category.replaceAll(RegExp(r'\s+'), ' ').trim();
                                      
                                      return Chip(
                                        label: Text(
                                          displayCategory,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        backgroundColor: displayCategory.toCategoryColor(),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        onDeleted: () {
                                          final newSelected = Set<String>.from(cardState.selectedCategories);
                                          newSelected.remove(category);
                                          ref.read(cardStateProvider.notifier)
                                              .updateSelectedCategories(newSelected);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
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
                        color: Colors.grey[600]
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Home',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/profile_icon.png',
                        width: 24,
                        height: 24,
                        color: Colors.black87
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        width: 140,
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
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
      ),
    );
  }
}

class ProfileBackgroundClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const curveHeight = 60.0;
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width / 2, -curveHeight, size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}