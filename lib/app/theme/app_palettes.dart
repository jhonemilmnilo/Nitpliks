import 'package:flutter/material.dart';

/// Represents a tailored visual palette theme for NitPliks
class AppPalette {
  final String id;
  final String name;
  final bool isDark;
  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppPalette({
    required this.id,
    required this.name,
    this.isDark = true,
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.border,
    this.textPrimary = const Color(0xFFF8FAFC),
    this.textSecondary = const Color(0xFF94A3B8),
    this.textMuted = const Color(0xFF64748B),
  });

  ThemeData get themeData {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              secondary: accent,
              surface: surface,
            )
          : ColorScheme.light(
              primary: primary,
              secondary: accent,
              surface: surface,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }
}

class AppPalettes {
  // ─── DARK THEMES ───

  // 1. Cyber Indigo
  static const cyberIndigo = AppPalette(
    id: 'cyber_indigo',
    name: 'Cyber Indigo',
    isDark: true,
    primary: Color(0xFF6366F1),
    primaryLight: Color(0xFF818CF8),
    accent: Color(0xFF06B6D4),
    background: Color(0xFF0B0F19),
    surface: Color(0xFF131B2E),
    surfaceLight: Color(0xFF1E293B),
    border: Color(0xFF202B3E),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );

  // 2. Cinema Crimson
  static const netflixCrimson = AppPalette(
    id: 'netflix_crimson',
    name: 'Cinema Crimson',
    isDark: true,
    primary: Color(0xFFE50914),
    primaryLight: Color(0xFFFF334B),
    accent: Color(0xFFFF5252),
    background: Color(0xFF0D0D0E),
    surface: Color(0xFF18181A),
    surfaceLight: Color(0xFF242428),
    border: Color(0xFF2C2C32),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
  );

  // 3. Emerald Matrix
  static const emeraldMatrix = AppPalette(
    id: 'emerald_matrix',
    name: 'Emerald Matrix',
    isDark: true,
    primary: Color(0xFF10B981),
    primaryLight: Color(0xFF34D399),
    accent: Color(0xFF2DD4BF),
    background: Color(0xFF08120F),
    surface: Color(0xFF0F1E19),
    surfaceLight: Color(0xFF1A2F28),
    border: Color(0xFF1E3A32),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );

  // 4. Amethyst Royal
  static const amethystRoyal = AppPalette(
    id: 'amethyst_royal',
    name: 'Amethyst Royal',
    isDark: true,
    primary: Color(0xFF8B5CF6),
    primaryLight: Color(0xFFA78BFA),
    accent: Color(0xFFEC4899),
    background: Color(0xFF0F0B18),
    surface: Color(0xFF1A1429),
    surfaceLight: Color(0xFF271F3D),
    border: Color(0xFF31264E),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );

  // 5. Sunset Amber
  static const sunsetAmber = AppPalette(
    id: 'sunset_amber',
    name: 'Sunset Amber',
    isDark: true,
    primary: Color(0xFFF59E0B),
    primaryLight: Color(0xFFFBBF24),
    accent: Color(0xFFFB923C),
    background: Color(0xFF140F08),
    surface: Color(0xFF201910),
    surfaceLight: Color(0xFF302619),
    border: Color(0xFF3D3020),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );

  // 6. Pure Obsidian (OLED)
  static const pureObsidian = AppPalette(
    id: 'pure_obsidian',
    name: 'Pure Obsidian',
    isDark: true,
    primary: Color(0xFF38BDF8),
    primaryLight: Color(0xFF7DD3FC),
    accent: Color(0xFF818CF8),
    background: Color(0xFF000000),
    surface: Color(0xFF101010),
    surfaceLight: Color(0xFF1C1C1C),
    border: Color(0xFF282828),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );

  // ─── LIGHT THEMES ───

  // 7. Clean Frost (Light Indigo)
  static const cleanFrost = AppPalette(
    id: 'clean_frost',
    name: 'Clean Frost',
    isDark: false,
    primary: Color(0xFF4F46E5),
    primaryLight: Color(0xFF6366F1),
    accent: Color(0xFF0284C7),
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
  );

  // 8. Sakura Rose (Light Blossom)
  static const sakuraRose = AppPalette(
    id: 'sakura_rose',
    name: 'Sakura Rose',
    isDark: false,
    primary: Color(0xFFE11D48),
    primaryLight: Color(0xFFF43F5E),
    accent: Color(0xFFFB7185),
    background: Color(0xFFFFF1F2),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFFFE4E6),
    border: Color(0xFFFECDD3),
    textPrimary: Color(0xFF881337),
    textSecondary: Color(0xFF9F1239),
    textMuted: Color(0xFFFDA4AF),
  );

  // 9. Fresh Mint (Light Sage)
  static const freshMint = AppPalette(
    id: 'fresh_mint',
    name: 'Fresh Mint',
    isDark: false,
    primary: Color(0xFF059669),
    primaryLight: Color(0xFF10B981),
    accent: Color(0xFF0D9488),
    background: Color(0xFFF0FDF4),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFDCFCE7),
    border: Color(0xFFBBF7D0),
    textPrimary: Color(0xFF064E3B),
    textSecondary: Color(0xFF047857),
    textMuted: Color(0xFF6EE7B7),
  );

  // 10. Warm Cream (Light Sand / Amber)
  static const warmCream = AppPalette(
    id: 'warm_cream',
    name: 'Warm Cream',
    isDark: false,
    primary: Color(0xFFD97706),
    primaryLight: Color(0xFFF59E0B),
    accent: Color(0xFFEA580C),
    background: Color(0xFFFFFBEB),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFFEF3C7),
    border: Color(0xFFFDE68A),
    textPrimary: Color(0xFF78350F),
    textSecondary: Color(0xFF92400E),
    textMuted: Color(0xFFFBBF24),
  );

  static const List<AppPalette> darkPalettes = [
    cyberIndigo,
    netflixCrimson,
    emeraldMatrix,
    amethystRoyal,
    sunsetAmber,
    pureObsidian,
  ];

  static const List<AppPalette> lightPalettes = [
    cleanFrost,
    sakuraRose,
    freshMint,
    warmCream,
  ];

  static const List<AppPalette> all = [
    cyberIndigo,
    netflixCrimson,
    emeraldMatrix,
    amethystRoyal,
    sunsetAmber,
    pureObsidian,
    cleanFrost,
    sakuraRose,
    freshMint,
    warmCream,
  ];

  static AppPalette getById(String? id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => cyberIndigo,
    );
  }
}
