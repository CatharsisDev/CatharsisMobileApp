import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
      : super(ThemeState(
          themeData: AppThemes.catharsisSignature,
          themeName: 'catharsis_signature',
        ));

  void setTheme(String themeName) {
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
        showBackgroundTexture: false,
        backgroundImagePath: null,
        categoryChipColor: Colors.blue,
        preferenceButtonColor: Colors.blue,
        preferenceModalBackgroundColor: Colors.white,
        preferenceItemSelectedColor: Color.fromRGBO(152, 117, 84, 0.1),
        preferenceItemUnselectedColor: Color.fromARGB(255, 251, 248, 231),
        preferenceBorderColor: Color(0xFF8B4F4F),
        profileAvatarColor: Color(0xFF987554),
        profileStatCardColor: Colors.transparent,
        profileStatIconBackgroundColor: Colors.white,
        profileContentBackgroundColor: Color.fromRGBO(255, 253, 240, 1),
        profileStatCardImagePath: null,
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
        profileStatIconBackgroundColor: Color(0xFF3D3D8A),
        profileContentBackgroundColor: Color.fromRGBO(46, 46, 89, 1),
        profileStatCardImagePath: "assets/images/dark_mode_stat_card.png",
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
    );
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>((ref) => ThemeNotifier());