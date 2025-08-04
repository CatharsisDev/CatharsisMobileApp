import 'package:catharsis_cards/pages/main_settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../provider/auth_provider.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/theme_provider.dart';
import '../../provider/user_profile_provider.dart';
import '../../services/user_profile_service.dart';
import '../../question_categories.dart';
import '../main_settings/settings_page.dart';
import 'package:go_router/go_router.dart';

class ProfilePageWidget extends ConsumerStatefulWidget {
  const ProfilePageWidget({super.key});

  @override
  ConsumerState<ProfilePageWidget> createState() => _ProfilePageWidgetState();
}

class _ProfilePageWidgetState extends ConsumerState<ProfilePageWidget> {

  final TextEditingController _avatarUsernameController = TextEditingController();
  final PageController _avatarController = PageController(viewportFraction: 0.3);
  int _avatarPage = 0;

  void _showAvatarSelectionDialog() {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final userProfile = ref.read(userProfileProvider);
    final initialUsername = userProfile.whenOrNull(data: (profile) => profile?.username) ?? '';
    _avatarUsernameController.text = initialUsername;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Consumer(
            builder: (context, sheetRef, _) {
              final currentAvatar = sheetRef.watch(userAvatarProvider);
              return Container(
                decoration: BoxDecoration(
                  color: customTheme?.preferenceModalBackgroundColor ?? theme.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
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
                          color: theme.brightness == Brightness.dark 
                              ? Colors.grey[500] 
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Choose Avatar',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 80,
                        child: PageView.builder(
                          controller: _avatarController,
                          itemCount: 6,
                          onPageChanged: (i) => setModalState(() => _avatarPage = i),
                          itemBuilder: (ctx, idx) {
                            final avatarAssets = [
                              'assets/images/avatar1.png',
                              'assets/images/avatar2.png',
                              'assets/images/avatar3.png',
                              'assets/images/avatar4.png',
                              'assets/images/avatar5.png',
                              'assets/images/avatar6.png',
                            ];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: _buildAvatarOption(
                                avatarAssets[idx],
                                currentAvatar,
                                theme,
                                customTheme,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _avatarPage == i
                                ? (customTheme?.profileAvatarColor ?? theme.primaryColor)
                                : (theme.textTheme.bodyMedium?.color ?? Colors.black).withOpacity(0.3),
                          ),
                        )),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Username',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _avatarUsernameController,
                              decoration: InputDecoration(
                                hintText: 'Enter username',
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: (() {
                                      final themeName = sheetRef.watch(themeProvider).themeName;
                                      return themeName == 'light'
                                          ? const Color(0xFF85A1AD)
                                          : const Color(0xFF987554);
                                    }()),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: (() {
                                      final themeName = sheetRef.watch(themeProvider).themeName;
                                      return themeName == 'light'
                                          ? const Color(0xFF85A1AD)
                                          : const Color(0xFF987554);
                                    }()),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (() {
                                    final themeName = sheetRef.watch(themeProvider).themeName;
                                    if (themeName == 'dark') return const Color.fromRGBO(232, 213, 255, 1);
                                    else if (themeName == 'light') return const Color.fromRGBO(252, 102, 77, 1);
                                    else return const Color(0xFF2A3F2C);
                                  }()),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  await ref.read(userProfileProvider.notifier).updateProfile(
                                    username: _avatarUsernameController.text.trim(),
                                  );
                                  Navigator.pop(context);
                                },
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAvatarOption(
    String? avatarPath,
    String? currentAvatar,
    ThemeData theme,
    CustomThemeExtension? customTheme, {
    bool isDefault = false,
  }) {
    final isSelected = currentAvatar == avatarPath;
    final authState = ref.watch(authStateProvider);
    final userProfile = ref.watch(userProfileProvider);
    
    return GestureDetector(
      onTap: () async {
        await ref.read(userProfileProvider.notifier).updateProfile(avatar: avatarPath);
        // Navigator.pop(context); // Removed to keep modal open after avatar selection
      },
      child: Container(
        width: 70,
        height: 70,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (customTheme?.profileAvatarColor ?? const Color(0xFF987554))
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (customTheme?.profileAvatarColor ?? const Color(0xFF987554)).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
          color: isDefault
              ? (customTheme?.profileAvatarColor ?? const Color(0xFF987554))
              : Colors.grey[200],
        ),
        child: isDefault
            ? Center(
                child: Text(
                  _getUserInitial(authState, userProfile),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  avatarPath!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
      ),
    );
  }

  String _getUserInitial(AsyncValue<User?> authState, AsyncValue<UserProfile?> userProfile) {
    // First try to get username from profile
    final username = userProfile.whenOrNull(data: (profile) => profile?.username);
    if (username != null && username.isNotEmpty) {
      return username.substring(0, 1).toUpperCase();
    }
    
    // Fallback to email
    final email = authState.whenOrNull(data: (user) => user?.email);
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    
    return 'U';
  }

  String _getDisplayName(AsyncValue<User?> authState, AsyncValue<UserProfile?> userProfile) {
    // First try to get username from profile
    final username = userProfile.whenOrNull(data: (profile) => profile?.username);
    if (username != null && username.isNotEmpty) {
      return username;
    }
    
    // Fallback to email prefix
    final email = authState.whenOrNull(data: (user) => user?.email);
    if (email != null && email.isNotEmpty) {
      return email.split('@')[0];
    }
    
    return 'User';
  }

  void _showCategoryFilterDialog() {
    final cardState = ref.read(cardStateProvider);
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    
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
                color: customTheme?.preferenceModalBackgroundColor ?? theme.cardColor,
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
                        color: theme.brightness == Brightness.dark 
                            ? Colors.grey[500] 
                            : Colors.grey[400],
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
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => tempSelected.clear()),
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: theme.brightness == Brightness.dark 
                                    ? Colors.grey[400] 
                                    : Colors.grey[600],
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
                                        ? (customTheme?.preferenceItemSelectedColor?.withOpacity(0.8) ?? Colors.grey[700])
                                        : (customTheme?.preferenceItemUnselectedColor ?? Colors.grey[800]), 
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: customTheme?.preferenceBorderColor ?? Colors.grey[600]!, 
                                      width: 1
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          display,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Runtime',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textTheme.bodyMedium?.color,
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
                              backgroundColor: customTheme?.preferenceButtonColor ?? theme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Apply',
                              style: TextStyle(
                                fontFamily: 'Runtime',
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
    final userProfile = ref.watch(userProfileProvider);
    final selectedAvatar = userProfile.whenOrNull(data: (profile) => profile?.avatar);
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                      opacity: 0.5,
                    )
                  : null,
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
                          color: theme.iconTheme.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          color: theme.textTheme.titleLarge?.color,
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
                            color: customTheme?.iconCircleColor ?? Colors.white.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/preferences_icon.png',
                              width: 24,
                              height: 24,
                              color: customTheme?.iconColor ?? theme.iconTheme.color,
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
                            color: customTheme?.iconCircleColor ?? Colors.white.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/settings_icon.png',
                              width: 24,
                              height: 24,
                              color: customTheme?.iconColor ?? theme.iconTheme.color,
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
                      // Background container that extends to bottom
                      Positioned(
                        top: 70,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: customTheme?.profileContentBackgroundColor ?? theme.cardColor,
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
                            
                            // User Avatar with theme-aware colors
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.cardColor,
                                border: Border.all(
                                  color: theme.brightness == Brightness.dark 
                                      ? (customTheme?.profileAvatarColor ?? const Color(0xFF2A2870))
                                      : Colors.white, 
                                  width: 8
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selectedAvatar == null 
                                      ? (customTheme?.profileAvatarColor ?? const Color(0xFF987554))
                                      : Colors.grey[200],
                                ),
                                child: ClipOval(
                                  child: selectedAvatar == null
                                      ? Center(
                                          child: Text(
                                            _getUserInitial(authState, userProfile),
                                            style: TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : Image.asset(
                                          selectedAvatar,
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Edit Avatar Button
                            GestureDetector(
                              onTap: _showAvatarSelectionDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: customTheme?.profileAvatarColor?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: customTheme?.profileAvatarColor ?? const Color(0xFF987554),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: customTheme?.profileAvatarColor ?? const Color(0xFF987554),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: customTheme?.profileAvatarColor ?? const Color(0xFF987554),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // User Name (shows username or email prefix)
                            Text(
                              _getDisplayName(authState, userProfile),
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                color: theme.textTheme.titleLarge?.color,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            // (User Email display removed)
                            
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
                                  theme,
                                  customTheme,
                                ),
                                const SizedBox(width: 16),
                                _buildStatCard(
                                  '${cardState.seenQuestions.length}',
                                  'Cards Seen',
                                  Icons.remove_red_eye,
                                  Colors.blue,
                                  theme,
                                  customTheme,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: customTheme?.profileContentBackgroundColor ?? theme.cardColor,
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
                            color: theme.brightness == Brightness.dark 
                                ? Colors.grey[400] 
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Home',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: theme.brightness == Brightness.dark 
                                  ? Colors.grey[400] 
                                  : Colors.grey[600],
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
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profile',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyMedium?.color,
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

  Widget _buildStatCard(String value, String title, IconData icon, Color color, 
                       ThemeData theme, CustomThemeExtension? customTheme) {
    return Container(
      width: 165,
      height: 190,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customTheme?.profileStatCardColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        image: (customTheme?.profileStatCardImagePath != null)
            ? DecorationImage(
                image: AssetImage(customTheme!.profileStatCardImagePath!),
                fit: BoxFit.cover,
                opacity: 0.6,
              )
            : (customTheme?.backgroundImagePath != null && theme.brightness != Brightness.dark)
                ? DecorationImage(
                    image: AssetImage(customTheme!.backgroundImagePath!),
                    fit: BoxFit.cover,
                    opacity: 0.4,
                  )
                : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: customTheme?.profileStatIconBackgroundColor ?? Colors.white,
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
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Runtime',
              fontSize: 14,
              color: theme.brightness == Brightness.dark 
                  ? Colors.grey[400] 
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _avatarUsernameController.dispose();
    super.dispose();
  }
}