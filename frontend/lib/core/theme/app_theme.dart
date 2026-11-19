import 'package:flutter/material.dart';

class AppTheme {
  // Brand color palette
  static const Color primaryColor = Color(0xFF4F46E5);      // Indigo 600
  static const Color primaryLight = Color(0xFF818CF8);      // Indigo 400
  static const Color primaryDark = Color(0xFF3730A3);       // Indigo 800
  static const Color accentColor = Color(0xFFF59E0B);       // Amber 500
  static const Color surfaceColor = Color(0xFFF8FAFC);      // Slate 50
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);       // Slate 900
  static const Color textSecondary = Color(0xFF64748B);     // Slate 500
  static const Color successColor = Color(0xFF10B981);      // Emerald 500
  static const Color warningColor = Color(0xFFF59E0B);      // Amber 500
  static const Color errorColor = Color(0xFFEF4444);        // Rose 500

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
    );
  }
}
