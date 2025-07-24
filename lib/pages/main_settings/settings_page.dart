import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../provider/auth_provider.dart';
import '../theme_settings/theme_settings_page.dart';
import '../liked_cards/liked_cards_widget.dart';

class SettingsMenuPage extends ConsumerWidget {
  const SettingsMenuPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          // Cream gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFAF1E1),
                  Color(0xFFFAF1E1).withOpacity(0.95),
                ],
              ),
            ),
          ),
          // Texture overlay
          Opacity(
            opacity: 0.3,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background_texture.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Original SafeArea content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: const Color.fromARGB(255, 0, 0, 0), size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Settings Options
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      SizedBox(height: 16),
                      
                      // Customize Theme
                      _buildSettingsItem(
                        icon: Icons.palette_outlined,
                        title: 'Customize theme',
                        assetIcon: 'assets/images/changetheme_icon.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ThemeSettingsPage(),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Saved Cards
                      _buildSettingsItem(
                        icon: FontAwesomeIcons.heart,
                        title: 'Saved',
                        assetIcon: 'assets/images/saved_icon.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LikedCardsWidget(),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: 40),
                      Divider(color: Colors.white24),
                      SizedBox(height: 20),
                      
                      // Log Out
                      _buildSettingsItem(
                        icon: Icons.logout,
                        title: 'Log out',
                        assetIcon: 'assets/images/logout_icon.png',
                        isRed: true,
                        onTap: () async {
                          // Show confirmation bottom sheet
                          final shouldLogout = await showModalBottomSheet<bool>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              padding: EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 4,
                                    margin: EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Text(
                                    'Log out',
                                    style: GoogleFonts.raleway(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Are you sure you want to log out?',
                                    style: GoogleFonts.raleway(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              side: BorderSide(color: Colors.grey[300]!),
                                            ),
                                          ),
                                          child: Text(
                                            'Cancel',
                                            style: GoogleFonts.raleway(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            'Log out',
                                            style: GoogleFonts.raleway(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                                ],
                              ),
                            ),
                          );
                          
                          if (shouldLogout == true) {
                            await authService.signOut();
                            // Navigation will happen automatically via auth state
                          }
                        },
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

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isRed = false,
    String? assetIcon,  // new optional asset path
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (assetIcon != null) 
              Image.asset(assetIcon, width: 24, height: 24)
            else if (icon == FontAwesomeIcons.bookmark)
              FaIcon(icon, color: isRed ? Colors.red : Colors.black87, size: 20)
            else
              Icon(icon, color: isRed ? Colors.red : Colors.black87, size: 20),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isRed ? Colors.red : Colors.black87,
              ),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}