import 'package:flutter/material.dart';

/// Represents a tailored visual palette theme for NitPliks
class AppPalette {
  final String id;
  final String name;
  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color border;

  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.border,
  });

  ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
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
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }
}

class AppPalettes {
  // 1. Cyber Indigo (Original High-Tech Streaming Vibe)
  static const cyberIndigo = AppPalette(
    id: 'cyber_indigo',
    name: 'Cyber Indigo',
    primary: Color(0xFF6366F1), // Neon Indigo
    primaryLight: Color(0xFF818CF8),
    accent: Color(0xFF06B6D4), // Cyan Glow
    background: Color(0xFF0B0F19), // Midnight Deep Navy
    surface: Color(0xFF131B2E),
    surfaceLight: Color(0xFF1E293B),
    border: Color(0xFF202B3E),
  );

  // 2. Netflix Crimson (Iconic Cinema Red & Coral)
  static const netflixCrimson = AppPalette(
    id: 'netflix_crimson',
    name: 'Cinema Crimson',
    primary: Color(0xFFE50914), // Netflix Red
    primaryLight: Color(0xFFFF334B),
    accent: Color(0xFFFF5252), // Coral Glow
    background: Color(0xFF0D0D0E), // Ultra Dark Carbon
    surface: Color(0xFF18181A),
    surfaceLight: Color(0xFF242428),
    border: Color(0xFF2C2C32),
  );

  // 3. Emerald Matrix (Modern Mint & Rich Emerald)
  static const emeraldMatrix = AppPalette(
    id: 'emerald_matrix',
    name: 'Emerald Matrix',
    primary: Color(0xFF10B981), // Emerald
    primaryLight: Color(0xFF34D399),
    accent: Color(0xFF2DD4BF), // Teal Mint
    background: Color(0xFF08120F), // Deep Forest Black
    surface: Color(0xFF0F1E19),
    surfaceLight: Color(0xFF1A2F28),
    border: Color(0xFF1E3A32),
  );

  // 4. Amethyst Royal (Synthwave Neon Purple & Pink)
  static const amethystRoyal = AppPalette(
    id: 'amethyst_royal',
    name: 'Amethyst Royal',
    primary: Color(0xFF8B5CF6), // Royal Purple
    primaryLight: Color(0xFFA78BFA),
    accent: Color(0xFFEC4899), // Hot Pink
    background: Color(0xFF0F0B18), // Void Violet
    surface: Color(0xFF1A1429),
    surfaceLight: Color(0xFF271F3D),
    border: Color(0xFF31264E),
  );

  // 5. Sunset Amber (Warm Gold & Citrus Orange)
  static const sunsetAmber = AppPalette(
    id: 'sunset_amber',
    name: 'Sunset Amber',
    primary: Color(0xFFF59E0B), // Warm Amber
    primaryLight: Color(0xFFFBBF24),
    accent: Color(0xFFFB923C), // Tangerine
    background: Color(0xFF140F08), // Dark Roast Charcoal
    surface: Color(0xFF201910),
    surfaceLight: Color(0xFF302619),
    border: Color(0xFF3D3020),
  );

  // 6. Pure Obsidian (True Pitch Black OLED & Sky Blue)
  static const pureObsidian = AppPalette(
    id: 'pure_obsidian',
    name: 'Pure Obsidian (OLED)',
    primary: Color(0xFF38BDF8), // Electric Sky Blue
    primaryLight: Color(0xFF7DD3FC),
    accent: Color(0xFF818CF8), // Soft Violet
    background: Color(0xFF000000), // Pure Black 000
    surface: Color(0xFF101010),
    surfaceLight: Color(0xFF1C1C1C),
    border: Color(0xFF282828),
  );

  static const List<AppPalette> all = [
    cyberIndigo,
    netflixCrimson,
    emeraldMatrix,
    amethystRoyal,
    sunsetAmber,
    pureObsidian,
  ];

  static AppPalette getById(String? id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => cyberIndigo,
    );
  }
}
