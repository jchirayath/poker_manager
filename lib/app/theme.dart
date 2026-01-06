import 'package:flutter/material.dart';

/// AppTheme - Centralized Material 3 theme configuration
/// 
/// Provides consistent light and dark themes throughout the application
/// using Material 3 design system with green as the primary seed color.
/// 
/// All screens should use Theme.of(context) to access theme colors,
/// text styles, and shape themes rather than hardcoding values.
class AppTheme {
  /// Light theme configuration
  /// 
  /// Uses Material 3 with green seed color and light brightness.
  /// Includes standardized shapes, input decoration, and button styles.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // Generate color scheme from seed color (green)
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      ),
      // Standardized AppBar styling - centered, no elevation
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      // Card styling - rounded corners with subtle elevation
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Input field styling - outlined border with 8px radius
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
      // Elevated button styling - consistent padding and border radius
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// Dark theme configuration
  /// 
  /// Uses Material 3 with green seed color and dark brightness.
  /// Maintains consistency with light theme but with dark background colors.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      // Generate color scheme from seed color (green) with dark brightness
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
      // Same AppBar styling as light theme
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      // Same card styling as light theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Same input styling as light theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
      // Same button styling as light theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
