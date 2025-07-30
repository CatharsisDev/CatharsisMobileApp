import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_provider.dart';

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier(this.ref) : super(ThemeState(
    themeData: AppThemes.catharsisSignature,
    themeName: 'catharsis_signature',
  )) {
    _init();
  }

  final Ref ref;
  String? _currentUserId;

  // Initialize theme loading and auth listener
  void _init() async {
    if (mounted) {
      _listenToAuthChanges();
    }
  }

  // Listen to auth state changes
  void _listenToAuthChanges() {
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final previousUser = previous?.whenOrNull(data: (user) => user);
      final currentUser = next.whenOrNull(data: (user) => user);
      
      // Only handle user changes, not logouts
      if (currentUser != null && currentUser.uid != _currentUserId) {
        _currentUserId = currentUser.uid;
        _loadThemeForUser(currentUser.uid);
      }
    });
  }

  // Load theme for specific user
  Future<void> _loadThemeForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use user-specific key for theme
      final savedTheme = prefs.getString('theme_$userId') ?? 'catharsis_signature';
      
      if (mounted) {
        setTheme(savedTheme, saveToStorage: false);
      }
    } catch (e) {
      print('Error loading theme for user: $e');
    }
  }

  // Save theme to storage with user-specific key
  Future<void> _saveTheme(String themeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId != null) {
        await prefs.setString('theme_$_currentUserId', themeName);
      }
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  void setTheme(String themeName, {bool saveToStorage = true}) {
    if (!mounted) return;
    
    if (saveToStorage) {
      _saveTheme(themeName);
    }
    
    switch (themeName) {
      case 'light':
        state = ThemeState(themeData: AppThemes.lightTheme, themeName: 'light');
        break;
      case 'dark':
        state = ThemeState(themeData: AppThemes.darkTheme, themeName: 'dark');
        break;
      case 'catharsis_signature':
      default:
        state = ThemeState(
            themeData: AppThemes.catharsisSignature,
            themeName: 'catharsis_signature');
        break;
    }
  }
}

class ThemeState {
  final ThemeData themeData;
  final String themeName;

  ThemeState({required this.themeData, required this.themeName});
}

class AppThemes {
  static final ThemeData catharsisSignature = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFFE35F42),
    scaffoldBackgroundColor: const Color(0xFFFAF1E1),
    cardColor: const Color(0xFFFAF1E1),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: 'Runtime',
        fontSize: 16,
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Runtime',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFAF1E1),
      iconTheme: IconThemeData(color: Colors.black87),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(const Color(0xFFE35F42)),
    ),
    extensions: const [
      CustomThemeExtension(
        showBackgroundTexture: true,
        backgroundImagePath: "assets/images/background_texture.png",
        profileStatCardImagePath: null,
        categoryChipColor: Color.fromRGBO(42, 63, 44, 1),
        preferenceButtonColor: Color.fromRGBO(42, 63, 44, 1),
        preferenceModalBackgroundColor: Color(0xFFFAF1E1),
        preferenceItemSelectedColor: Color.fromRGBO(152, 117, 84, 1),
        preferenceItemUnselectedColor: Color.fromARGB(255, 251, 248, 231),
        preferenceBorderColor: Color(0xFF8B4F4F),
        profileAvatarColor: Color(0xFF987554),
        profileStatCardColor: Colors.transparent,
        profileStatIconBackgroundColor: Colors.white,
        profileContentBackgroundColor: Color.fromRGBO(255, 253, 240, 1),
        iconColor: Color.fromRGBO(152, 117, 84, 1),
        iconCircleColor: Color.fromRGBO(152, 117, 84, 0.1),
        likeAndShareIconColor: Color.fromRGBO(152, 117, 84, 1),
      ),
    ],
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: 'Runtime',
        fontSize: 16,
        color: Colors.black,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Runtime',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(Colors.blue),
    ),
    extensions: const [
      CustomThemeExtension(
        showBackgroundTexture: true,
        backgroundImagePath: "assets/images/light_mode_background.png",
        categoryChipColor: Color.fromRGBO(212, 221, 255, 1),
        preferenceButtonColor: Color.fromRGBO(242, 209, 209, 1),
        preferenceModalBackgroundColor: Colors.white,
        preferenceItemSelectedColor: Color.fromRGBO(227, 227, 227, 1),
        preferenceItemUnselectedColor: Color.fromRGBO(255, 255, 255, 1),
        preferenceBorderColor: Color.fromARGB(255, 214, 214, 214),
        profileAvatarColor: Color.fromRGBO(242, 209, 209, 1),
        profileStatCardColor: Colors.transparent,
        profileStatIconBackgroundColor: Colors.white,
        profileContentBackgroundColor: Colors.white,
        profileStatCardImagePath: "assets/images/light_mode_stat_card.png",
        iconColor: Color.fromRGBO(133, 161, 173, 1),
        iconCircleColor: Color.fromRGBO(133, 161, 173, 0.1),
        likeAndShareIconColor: Color.fromRGBO(98, 98, 113, 1),
      ),
    ],
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF100E42),
    scaffoldBackgroundColor: const Color(0xFF100E42),
    cardColor: const Color(0xFF1A1654),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: 'Runtime',
        fontSize: 16,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Runtime',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF100E42),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(Colors.white),
    ),
    extensions: const [
      CustomThemeExtension(
        showBackgroundTexture: true,
        backgroundImagePath: "assets/images/dark_mode_background.png",
        categoryChipColor: Color(0xFF2A2870),
        preferenceButtonColor: Color.fromRGBO(232, 213, 255, 1),
        preferenceModalBackgroundColor: Color(0xFF0F0D3A),
        preferenceItemSelectedColor: Color(0xFF3D3D8A),
        preferenceItemUnselectedColor: Color(0xFF252566),
        preferenceBorderColor: Color(0xFF4A4A95),
        profileAvatarColor: Color.fromRGBO(232, 213, 255, 1),
        profileStatCardColor: Color(0xFF252566),
        profileStatIconBackgroundColor: Color.fromRGBO(46, 46, 89, 1),
        profileContentBackgroundColor: Color.fromRGBO(46, 46, 89, 1),
        profileStatCardImagePath: "assets/images/dark_mode_stat_card.png",
        iconColor: Color.fromRGBO(237, 239, 220, 1),
        iconCircleColor: Color.fromRGBO(255, 255, 255, 0.1),
        likeAndShareIconColor: Color.fromRGBO(237, 239, 220, 1),
      ),
    ],
  );
}

@immutable
class CustomThemeExtension extends ThemeExtension<CustomThemeExtension> {
  final bool showBackgroundTexture;
  final String? backgroundImagePath;
  final Color categoryChipColor;
  final Color preferenceButtonColor;
  final Color preferenceModalBackgroundColor;
  final Color preferenceItemSelectedColor;
  final Color preferenceItemUnselectedColor;
  final Color preferenceBorderColor;
  final Color profileAvatarColor;
  final Color profileStatCardColor;
  final Color profileStatIconBackgroundColor;
  final Color profileContentBackgroundColor;
  final String? profileStatCardImagePath;
  final Color iconColor; 
  final Color? iconCircleColor; 
  final Color? likeAndShareIconColor;
  
  const CustomThemeExtension({
    required this.showBackgroundTexture,
    required this.backgroundImagePath,
    required this.categoryChipColor,
    required this.preferenceButtonColor,
    required this.preferenceModalBackgroundColor,
    required this.preferenceItemSelectedColor,
    required this.preferenceItemUnselectedColor,
    required this.preferenceBorderColor,
    required this.profileAvatarColor,
    required this.profileStatCardColor,
    required this.profileStatIconBackgroundColor,
    required this.profileContentBackgroundColor,
    required this.profileStatCardImagePath,
    required this.iconColor,
    required this.iconCircleColor,
    required this.likeAndShareIconColor,
  });

  @override
  CustomThemeExtension copyWith({
    bool? showBackgroundTexture,
    String? backgroundImagePath,
    Color? categoryChipColor,
    Color? preferenceButtonColor,
    Color? preferenceModalBackgroundColor,
    Color? preferenceItemSelectedColor,
    Color? preferenceItemUnselectedColor,
    Color? preferenceBorderColor,
    Color? profileAvatarColor,
    Color? profileStatCardColor,
    Color? profileStatIconBackgroundColor,
    Color? profileContentBackgroundColor,
    String? profileStatCardImagePath,
    Color? iconColor,
    Color? iconCircleColor,
    Color? likeAndShareIconColor,
  }) {
    return CustomThemeExtension(
      showBackgroundTexture: showBackgroundTexture ?? this.showBackgroundTexture,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      categoryChipColor: categoryChipColor ?? this.categoryChipColor,
      preferenceButtonColor: preferenceButtonColor ?? this.preferenceButtonColor,
      preferenceModalBackgroundColor: preferenceModalBackgroundColor ?? this.preferenceModalBackgroundColor,
      preferenceItemSelectedColor: preferenceItemSelectedColor ?? this.preferenceItemSelectedColor,
      preferenceItemUnselectedColor: preferenceItemUnselectedColor ?? this.preferenceItemUnselectedColor,
      preferenceBorderColor: preferenceBorderColor ?? this.preferenceBorderColor,
      profileAvatarColor: profileAvatarColor ?? this.profileAvatarColor,
      profileStatCardColor: profileStatCardColor ?? this.profileStatCardColor,
      profileStatIconBackgroundColor: profileStatIconBackgroundColor ?? this.profileStatIconBackgroundColor,
      profileContentBackgroundColor: profileContentBackgroundColor ?? this.profileContentBackgroundColor,
      profileStatCardImagePath: profileStatCardImagePath ?? this.profileStatCardImagePath,
      iconColor: iconColor ?? this.iconColor, 
      iconCircleColor: iconCircleColor ?? this.iconCircleColor,  
      likeAndShareIconColor: likeAndShareIconColor ?? this.likeAndShareIconColor,
    );
  }

  @override
  CustomThemeExtension lerp(ThemeExtension<CustomThemeExtension>? other, double t) {
    if (other is! CustomThemeExtension) {
      return this;
    }
    return CustomThemeExtension(
      showBackgroundTexture: t < 0.5 ? showBackgroundTexture : other.showBackgroundTexture,
      backgroundImagePath: t < 0.5 ? backgroundImagePath : other.backgroundImagePath,
      categoryChipColor: Color.lerp(categoryChipColor, other.categoryChipColor, t)!,
      preferenceButtonColor: Color.lerp(preferenceButtonColor, other.preferenceButtonColor, t)!,
      preferenceModalBackgroundColor: Color.lerp(preferenceModalBackgroundColor, other.preferenceModalBackgroundColor, t)!,
      preferenceItemSelectedColor: Color.lerp(preferenceItemSelectedColor, other.preferenceItemSelectedColor, t)!,
      preferenceItemUnselectedColor: Color.lerp(preferenceItemUnselectedColor, other.preferenceItemUnselectedColor, t)!,
      preferenceBorderColor: Color.lerp(preferenceBorderColor, other.preferenceBorderColor, t)!,
      profileAvatarColor: Color.lerp(profileAvatarColor, other.profileAvatarColor, t)!,
      profileStatCardColor: Color.lerp(profileStatCardColor, other.profileStatCardColor, t)!,
      profileStatIconBackgroundColor: Color.lerp(profileStatIconBackgroundColor, other.profileStatIconBackgroundColor, t)!,
      profileContentBackgroundColor: Color.lerp(profileContentBackgroundColor, other.profileContentBackgroundColor, t)!,
      profileStatCardImagePath: t < 0.5 ? profileStatCardImagePath : other.profileStatCardImagePath,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      iconCircleColor: Color.lerp(iconCircleColor, other.iconCircleColor, t),
      likeAndShareIconColor: Color.lerp(likeAndShareIconColor, other.likeAndShareIconColor, t),
    );
  }
}

// Updated provider that passes ref to ThemeNotifier
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) => ThemeNotifier(ref));