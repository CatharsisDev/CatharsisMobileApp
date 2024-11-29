import 'package:flutter/material.dart';

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