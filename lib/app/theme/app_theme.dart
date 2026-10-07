import 'package:flutter/material.dart';

/// Design tokens for NitPliks (OLED dark theme, modern glassmorphism accents)
class AppTheme {
  // Brand & Accent Colors
  static const Color primary = Color(0xFF6366F1); // Indigo neon accent
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFF06B6D4); // Cyan glow
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber

  // Backgrounds & Surfaces (True Dark / OLED Friendly)
  static const Color background = Color(0xFF0B0F19); // Midnight Deep Navy
  static const Color surface = Color(0xFF131B2E); // Deep Card Slate
  static const Color surfaceLight = Color(0xFF1E293B); // Raised Surface
  static const Color surfaceHighlight = Color(0xFF27354E);

  // Border & Divider Colors
  static const Color border = Color(0xFF202B3E);
  static const Color borderLight = Color(0xFF334155);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Modern Dark ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
    );
  }
}
