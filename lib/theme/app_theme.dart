import 'package:flutter/material.dart';

class AppTheme {
  // Vibrant Accent Colors (Sunset Orange to Magenta)
  static const Color primaryAccent = Color(0xFFFF512F); // Sunset Orange
  static const Color secondaryAccent = Color(0xFFDD2476); // Magenta
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Colors.white;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryAccent, secondaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: lightSurface,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: darkSurface,
      ),
      useMaterial3: true,
    );
  }
}
