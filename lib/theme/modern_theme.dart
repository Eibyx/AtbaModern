import 'package:flutter/material.dart';

class ModernTheme {
  static const accent = Color(0xFF26D49A);
  static ThemeData build(Brightness brightness, {ColorScheme? dynamicColors}) {
    final dark = brightness == Brightness.dark;
    final colors =
        dynamicColors ??
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: dark ? const Color(0xFF101418) : const Color(0xFFF5F8F7),
          primary: dark ? accent : const Color(0xFF006C4B),
          surfaceContainer: dark
              ? const Color(0xFF1B2229)
              : const Color(0xFFE8EFEB),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: 'inter',
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainer,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainer,
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  static ThemeMode mode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
