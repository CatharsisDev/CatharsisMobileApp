import 'package:catharsis_cards/pages/account_settings/acount_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../provider/auth_provider.dart';
import '../../provider/theme_provider.dart';
import '../../provider/app_state_provider.dart';
import 'package:url_launcher/url_launcher.dart' show canLaunchUrl, launchUrl, LaunchMode;
import '../theme_settings/theme_settings_page.dart';
import '../liked_cards/liked_cards_widget.dart';
import 'package:catharsis_cards/services/account_deletion_service.dart';

class SettingsMenuPage extends ConsumerWidget {
  const SettingsMenuPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    
    return Scaffold(
      body: Stack(
        children: [
          // Theme-aware background
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              image: (customTheme?.showBackgroundTexture ?? false) && 
                     (customTheme?.backgroundImagePath != null)
                  ? DecorationImage(
                      image: AssetImage(customTheme!.backgroundImagePath!),
                      fit: BoxFit.cover,
                      opacity: 0.3,
                    )
                  : null,
            ),
          ),
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
                        icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
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
                      
                      // Delete Account
                      _buildSettingsItem(
                        context: context,
                        theme: theme,
                        icon: Icons.delete_forever,
                        title: 'Delete account',
                        isRed: true,
                        onTap: () async {
                          // Hand off the whole flow (confirmation + loading + deletion + navigation) to the service
                          await AccountDeletionService().deleteAccountFlow(context);
                        },
                      ),
                      SizedBox(height: 16),
                      
                      // Customize Theme
                      _buildSettingsItem(
                        context: context,
                        theme: theme,
                        icon: Icons.palette_outlined,
                        title: 'App appearance',
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
                        context: context,
                        theme: theme,
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
                      
                      SizedBox(height: 16),

                      // Account Settings
                      _buildSettingsItem(
                        context: context,
                        theme: theme,
                        icon: Icons.person,
                        title: 'Account',
                        assetIcon: 'assets/images/profile_icon.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountSettingsPage(),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: 16),

                      SizedBox(height: 40),
                      Divider(color: theme.brightness == Brightness.dark ? Colors.white24 : Colors.grey[300]),
                      SizedBox(height: 20),

                      
                      
                      // Log Out
                      _buildSettingsItem(
                        context: context,
                        theme: theme,
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
                                color: theme.cardColor,
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
                                      color: theme.brightness == Brightness.dark 
                                          ? Colors.grey[600] 
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Text(
                                    'Log out',
                                    style: TextStyle(
                                      fontFamily: 'Runtime',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.titleLarge?.color,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Are you sure you want to log out?',
                                    style: TextStyle(
                                      fontFamily: 'Runtime',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.brightness == Brightness.dark 
                                          ? Colors.grey[400] 
                                          : Colors.grey[600],
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
                                              side: BorderSide(
                                                color: theme.brightness == Brightness.dark 
                                                    ? Colors.grey[600]! 
                                                    : Colors.grey[300]!
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              fontFamily: 'Runtime',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: theme.brightness == Brightness.dark 
                                                  ? Colors.grey[300] 
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: customTheme?.preferenceButtonColor ?? theme.primaryColor,
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            'Log out',
                                            style: TextStyle(
                                              fontFamily: 'Runtime',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
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
                            try {
                              // Show loading indicator
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => WillPopScope(
                                  onWillPop: () async => false,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              );

                              // Clear user-specific data before invalidating providers
                              final cardStateNotifier = ref.read(cardStateProvider.notifier);
                              await cardStateNotifier.clearUserData();
                              
                              // Sign out (this will trigger navigation via router)
                              await authService.signOut();
                              
                              // Don't manually navigate - let the router handle it
                              // The auth state change will trigger the router to redirect to login
                              
                            } catch (e) {
                              // Only pop the loading dialog if context is still mounted
                              if (context.mounted) {
                                Navigator.of(context, rootNavigator: true).pop(); // Pop loading dialog only
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error signing out: ${e.toString()}',
                                      style: TextStyle(fontFamily: 'Runtime'),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      SizedBox(height: 16),
                      _buildSettingsItem(
                        context: context,
                        theme: theme,
                        icon: Icons.privacy_tip,
                        title: 'Privacy Policy',
                        onTap: () async {
                          final Uri url = Uri.parse('https://sendn00ts.github.io/CatharsisMobileApp/');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not open privacy policy.',
                                  style: TextStyle(fontFamily: 'Runtime'),
                                ),
                              ),
                            );
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
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isRed = false,
    String? assetIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
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
              Image.asset(
                assetIcon, 
                width: 24, 
                height: 24,
                color: isRed ? Colors.red : theme.iconTheme.color,
              )
            else if (icon == FontAwesomeIcons.bookmark)
              FaIcon(icon, color: isRed ? Colors.red : theme.iconTheme.color, size: 20)
            else
              Icon(icon, color: isRed ? Colors.red : theme.iconTheme.color, size: 20),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isRed ? Colors.red : theme.textTheme.bodyMedium?.color,
              ),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}