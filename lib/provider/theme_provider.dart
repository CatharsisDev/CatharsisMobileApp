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
    // Custom properties via extension
    extensions: const [
      CustomThemeExtension(
        showBackgroundTexture: true,
        categoryChipColor: Color.fromRGBO(42, 63, 44, 1),
        preferenceButtonColor: Color.fromRGBO(42, 63, 44, 1),
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
        categoryChipColor: Colors.blue,
        preferenceButtonColor: Colors.blue,
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
        showBackgroundTexture: false,
        categoryChipColor: Color(0xFF2A2870),
        preferenceButtonColor: Color(0xFF2A2870),
      ),
    ],
  );
}

// Custom theme extension for additional properties
@immutable
class CustomThemeExtension extends ThemeExtension<CustomThemeExtension> {
  final bool showBackgroundTexture;
  final Color categoryChipColor;
  final Color preferenceButtonColor;

  const CustomThemeExtension({
    required this.showBackgroundTexture,
    required this.categoryChipColor,
    required this.preferenceButtonColor,
  });

  @override
  CustomThemeExtension copyWith({
    bool? showBackgroundTexture,
    Color? categoryChipColor,
    Color? preferenceButtonColor,
  }) {
    return CustomThemeExtension(
      showBackgroundTexture: showBackgroundTexture ?? this.showBackgroundTexture,
      categoryChipColor: categoryChipColor ?? this.categoryChipColor,
      preferenceButtonColor: preferenceButtonColor ?? this.preferenceButtonColor,
    );
  }

  @override
  CustomThemeExtension lerp(ThemeExtension<CustomThemeExtension>? other, double t) {
    if (other is! CustomThemeExtension) {
      return this;
    }
    return CustomThemeExtension(
      showBackgroundTexture: t < 0.5 ? showBackgroundTexture : other.showBackgroundTexture,
      categoryChipColor: Color.lerp(categoryChipColor, other.categoryChipColor, t)!,
      preferenceButtonColor: Color.lerp(preferenceButtonColor, other.preferenceButtonColor, t)!,
    );
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>((ref) => ThemeNotifier());