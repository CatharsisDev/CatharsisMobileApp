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
    primaryColor: const Color(0xFFE35F42),
    scaffoldBackgroundColor: const Color.fromARGB(235, 208, 164, 180),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: 'Raleway',
        fontSize: 16,
        color: Colors.white,
      ),
    ),
    appBarTheme: const AppBarTheme(
      color: Color.fromARGB(235, 208, 164, 180),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(const Color.fromARGB(255, 227, 95, 66)),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    primaryColor: Colors.white,
    scaffoldBackgroundColor: Colors.white,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: 'Raleway',
        fontSize: 16,
        color: Colors.black,
      ),
    ),
    appBarTheme: const AppBarTheme(
      color: Colors.white,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(Colors.orange),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    primaryColor: Colors.black,
    scaffoldBackgroundColor: Colors.black,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: 'Raleway',
        fontSize: 16,
        color: Colors.white,
      ),
    ),
    appBarTheme: const AppBarTheme(
      color: Colors.black,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(Colors.orange),
    ),
  );
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>((ref) => ThemeNotifier());