import 'package:flutter/material.dart';

/// Midnight Glass v2 theme for ClassMate (maroon/teal glass).
ThemeData buildTheme() {
  const primary = Color(0xFFA51C30);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
    primary: primary,
  ).copyWith(
    primary: primary,
    secondary: const Color(0xFFAEB8BD),
    surface: const Color(0xFF182528).withValues(alpha: 0.92),
    surfaceContainerLowest: const Color(0xFF0C1215),
    surfaceContainerLow: const Color(0xFF131E21),
    surfaceContainer: const Color(0xFF182528),
    surfaceContainerHigh: const Color(0xFF1E3033),
    surfaceContainerHighest: const Color(0xFF243A3D),
    onSurface: const Color(0xFFF1F6F2),
    onPrimary: Colors.white,
    outline: const Color(0xFFCDE9DC).withValues(alpha: 0.14),
    outlineVariant: const Color(0xFFCDE9DC).withValues(alpha: 0.08),
    error: const Color(0xFFEE7C86),
  );

  const textMain = Color(0xFFF1F6F2);
  const textMuted = Color(0xFFA7B8B0);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: const Color(0xFF0C1215).withValues(alpha: 0.82),
      surfaceTintColor: Colors.transparent,
      foregroundColor: textMain,
      titleTextStyle: const TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF182528).withValues(alpha: 0.82),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFFCDE9DC).withValues(alpha: 0.12)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF131E21).withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: const Color(0xFFCDE9DC).withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: const Color(0xFFCDE9DC).withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primary.withValues(alpha: 0.9)),
      ),
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF243A3D),
        foregroundColor: textMain,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0C1215).withValues(alpha: 0.9),
      surfaceTintColor: Colors.transparent,
      indicatorColor: primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const IconThemeData(color: textMain);
        return const IconThemeData(color: textMuted);
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFF131E21).withValues(alpha: 0.9),
      indicatorColor: primary.withValues(alpha: 0.22),
      selectedIconTheme: const IconThemeData(color: textMain),
      unselectedIconTheme: const IconThemeData(color: textMuted),
      selectedLabelTextStyle: const TextStyle(color: textMain, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: const TextStyle(color: textMuted),
    ),
    dividerTheme: DividerThemeData(color: const Color(0xFFCDE9DC).withValues(alpha: 0.1)),
    chipTheme: ChipThemeData(
      backgroundColor: primary.withValues(alpha: 0.14),
      side: BorderSide(color: primary.withValues(alpha: 0.3)),
      labelStyle: const TextStyle(color: textMain),
    ),
    listTileTheme: const ListTileThemeData(iconColor: textMuted, textColor: textMain),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF182528).withValues(alpha: 0.98),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFFCDE9DC).withValues(alpha: 0.12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF182528),
      contentTextStyle: const TextStyle(color: textMain),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
