import 'package:flutter/material.dart';

/// Palette that mirrors the ClassMate 2.0 "Midnight Glass" web design.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.card,
    required this.cardHover,
    required this.glass,
    required this.border,
    required this.borderGlow,
    required this.textMain,
    required this.textMuted,
    required this.textDim,
    required this.primary,
    required this.primarySoft,
    required this.emerald,
    required this.amber,
    required this.rose,
    required this.violet,
    required this.heroGradient,
    required this.isDark,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color card;
  final Color cardHover;
  final Color glass;
  final Color border;
  final Color borderGlow;
  final Color textMain;
  final Color textMuted;
  final Color textDim;
  final Color primary;
  final Color primarySoft;
  final Color emerald;
  final Color amber;
  final Color rose;
  final Color violet;
  final List<Color> heroGradient;
  final bool isDark;

  static const dark = AppColors(
    bgPrimary: Color(0xFF0C1215),
    bgSecondary: Color(0xFF131E21),
    card: Color(0xD1182527),
    cardHover: Color(0xEB203132),
    glass: Color(0xD10C1417),
    border: Color(0x1FCDE9DC),
    borderGlow: Color(0x61A51C30),
    textMain: Color(0xFFF1F6F2),
    textMuted: Color(0xFFA7B8B0),
    textDim: Color(0xFF788A82),
    primary: Color(0xFFA51C30),
    primarySoft: Color(0x29A51C30),
    emerald: Color(0xFF53C99A),
    amber: Color(0xFFEDBD68),
    rose: Color(0xFFEE7C86),
    violet: Color(0xFF78858B),
    heroGradient: [Color(0xFF0E1112), Color(0xFF211316), Color(0xFF4B121D)],
    isDark: true,
  );

  static const light = AppColors(
    bgPrimary: Color(0xFFEEF4F1),
    bgSecondary: Color(0xFFE4EDE8),
    card: Color(0xE6FAFDFB),
    cardHover: Color(0xFFFFFFFF),
    glass: Color(0xDBF4F9F6),
    border: Color(0x262A483E),
    borderGlow: Color(0x40A51C30),
    textMain: Color(0xFF1B2B26),
    textMuted: Color(0xFF52675E),
    textDim: Color(0xFF77887F),
    primary: Color(0xFFA51C30),
    primarySoft: Color(0x17A51C30),
    emerald: Color(0xFF21845F),
    amber: Color(0xFF96610B),
    rose: Color(0xFFBD4B5A),
    violet: Color(0xFF59636C),
    heroGradient: [Color(0xFF1B1214), Color(0xFF2C171B), Color(0xFF5A1724)],
    isDark: false,
  );

  @override
  AppColors copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? card,
    Color? cardHover,
    Color? glass,
    Color? border,
    Color? borderGlow,
    Color? textMain,
    Color? textMuted,
    Color? textDim,
    Color? primary,
    Color? primarySoft,
    Color? emerald,
    Color? amber,
    Color? rose,
    Color? violet,
    List<Color>? heroGradient,
    bool? isDark,
  }) {
    return AppColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      card: card ?? this.card,
      cardHover: cardHover ?? this.cardHover,
      glass: glass ?? this.glass,
      border: border ?? this.border,
      borderGlow: borderGlow ?? this.borderGlow,
      textMain: textMain ?? this.textMain,
      textMuted: textMuted ?? this.textMuted,
      textDim: textDim ?? this.textDim,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      emerald: emerald ?? this.emerald,
      amber: amber ?? this.amber,
      rose: rose ?? this.rose,
      violet: violet ?? this.violet,
      heroGradient: heroGradient ?? this.heroGradient,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardHover: Color.lerp(cardHover, other.cardHover, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderGlow: Color.lerp(borderGlow, other.borderGlow, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      heroGradient: [
        Color.lerp(heroGradient[0], other.heroGradient[0], t)!,
        Color.lerp(heroGradient[1], other.heroGradient[1], t)!,
        Color.lerp(heroGradient[2], other.heroGradient[2], t)!,
      ],
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme([Brightness brightness = Brightness.dark]) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: brightness,
        primary: c.primary,
        surface: c.bgSecondary,
        error: c.rose,
      ).copyWith(
        primary: c.primary,
        onPrimary: Colors.white,
        secondary: c.emerald,
        surface: c.bgSecondary,
        onSurface: c.textMain,
        outline: c.border,
        outlineVariant: c.border,
        error: c.rose,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    extensions: [c],
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textMain,
      titleTextStyle: TextStyle(
        color: c.textMain,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.isDark ? const Color(0xB3131E21) : const Color(0xFFF9FCFA),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.primary.withValues(alpha: 0.9)),
      ),
      labelStyle: TextStyle(color: c.textMuted),
      hintStyle: TextStyle(color: c.textDim),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.cardHover,
        foregroundColor: c.textMain,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primary),
    ),
    dividerTheme: DividerThemeData(color: c.border, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: c.primarySoft,
      side: BorderSide(color: c.border),
      labelStyle: TextStyle(color: c.textMain, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textMuted,
      textColor: c.textMain,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.isDark
          ? const Color(0xFF182528)
          : const Color(0xFFF9FCFA),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.isDark
          ? const Color(0xFF182528)
          : const Color(0xFFF9FCFA),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.isDark
          ? const Color(0xFF203132)
          : const Color(0xFF1B2B26),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.border,
      circularTrackColor: c.border,
    ),
  );
}
