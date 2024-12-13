import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static ThemeData catharsisSignature = ThemeData(
    primaryColor: const Color(0xFFE35F42),
    scaffoldBackgroundColor: const Color.fromARGB(235, 208, 164, 180),
    textTheme: TextTheme(
      bodyMedium: GoogleFonts.raleway(
        fontSize: 16,
        color: Colors.white,
      ),
      titleLarge: GoogleFonts.raleway(
        fontSize: 22,
        fontWeight: FontWeight.bold,
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
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFE35F42),
      secondary: Color.fromARGB(255, 140, 198, 255),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    textTheme: TextTheme(
      bodyMedium: GoogleFonts.raleway(
        fontSize: 16,
        color: Colors.black,
      ),
      titleLarge: GoogleFonts.raleway(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),
    appBarTheme: const AppBarTheme(
      color: Colors.white,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(Colors.blue),
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blue.shade200,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: Colors.deepPurple,
    scaffoldBackgroundColor: const Color.fromRGBO(255, 0, 0, 1),
    textTheme: TextTheme(
      bodyMedium: GoogleFonts.raleway(
        fontSize: 16,
        color: Colors.white,
      ),
      titleLarge: GoogleFonts.raleway(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    appBarTheme: AppBarTheme(
      color: const Color.fromARGB(255, 255, 255, 255),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(Colors.deepPurple),
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.deepPurple,
      secondary: Colors.deepPurple.shade200,
    ),
  );
}