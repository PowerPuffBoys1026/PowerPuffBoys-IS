import 'package:flutter/material.dart';

abstract final class PortalColors {
  // Brand Primary & Accents (Vibrant, modern student aesthetic)
  static const primary = Color(0xFF6366F1); // Electric Indigo
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF4F46E5);
  static const primaryWash = Color(0xFFEEF2FF);

  static const cyan = Color(0xFF0EA5E9); // Sky Cyan
  static const emerald = Color(0xFF10B981); // Emerald Green
  static const emeraldWash = Color(0xFFECFDF5);
  static const amber = Color(0xFFF59E0B); // Amber / Gold
  static const rose = Color(0xFFF43F5E); // Sunset Rose
  static const violet = Color(0xFF8B5CF6); // Neon Violet

  // Light Mode Neutrals
  static const inkLight = Color(0xFF0F172A);
  static const mutedLight = Color(0xFF64748B);
  static const paperLight = Color(0xFFF8FAFC);
  static const surfaceLight = Colors.white;
  static const lineLight = Color(0xFFE2E8F0);

  // Dark Mode Neutrals
  static const inkDark = Color(0xFFF8FAFC);
  static const mutedDark = Color(0xFF94A3B8);
  static const paperDark = Color(0xFF090D16);
  static const surfaceDark = Color(0xFF131A2A);
  static const cardDark = Color(0xFF182236);
  static const lineDark = Color(0xFF1E293B);

  // Backwards compatibility with previous portal naming
  static const ink = inkLight;
  static const muted = mutedLight;
  static const paper = paperLight;
  static const line = lineLight;
  static const crimson = primary;
  static const crimsonWash = primaryWash;
  static const forest = emerald;
  static const gold = amber;
}

abstract final class AppGradients {
  static const primary = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const focus = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const success = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warning = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const fire = LinearGradient(
    colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGlassDark = LinearGradient(
    colors: [Color(0xFF1A2338), Color(0xFF131A2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme([Brightness brightness = Brightness.light]) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: PortalColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: PortalColors.primary,
    onPrimary: Colors.white,
    secondary: PortalColors.emerald,
    tertiary: PortalColors.amber,
    surface: isDark ? PortalColors.surfaceDark : PortalColors.surfaceLight,
    error: const Color(0xFFEF4444),
  );

  final baseText = (isDark ? ThemeData.dark() : ThemeData.light())
      .textTheme
      .apply(
        bodyColor: isDark ? PortalColors.inkDark : PortalColors.inkLight,
        displayColor: isDark ? PortalColors.inkDark : PortalColors.inkLight,
        fontFamily: 'Avenir Next',
      );

  final cardColor = isDark ? PortalColors.cardDark : PortalColors.surfaceLight;
  final borderColor = isDark ? PortalColors.lineDark : PortalColors.lineLight;
  final scaffoldBg = isDark ? PortalColors.paperDark : PortalColors.paperLight;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBg,
    cardColor: cardColor,
    dividerColor: borderColor,
    textTheme: baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        color: isDark ? PortalColors.mutedDark : PortalColors.mutedLight,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: scaffoldBg,
      foregroundColor: isDark ? PortalColors.inkDark : PortalColors.inkLight,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: isDark ? 0 : 0.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: borderColor,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF131A2A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? PortalColors.surfaceDark : Colors.white,
      indicatorColor: isDark ? const Color(0xFF28344E) : PortalColors.primaryWash,
      elevation: 3,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? PortalColors.primary
              : (isDark ? PortalColors.mutedDark : PortalColors.mutedLight),
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PortalColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
