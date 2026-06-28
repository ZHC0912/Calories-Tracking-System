import 'package:flutter/material.dart';

/// Visual direction: photo-first, warm and friendly — not clinical.
///
/// A single confident accent on a warm off-white background, rounded cards, and
/// generous spacing so food photos have room to breathe. The accent is
/// user-selectable (see [accentOptions] / theme_provider.dart); widgets read the
/// live value via `context.accent` so a change applies everywhere instantly.
class AppTheme {
  AppTheme._();

  /// Default accent; users can pick another from [accentOptions] in Settings.
  static const Color defaultAccent = Color(0xFFF4683C); // warm coral
  static const Color background = Color(0xFFFFFBF6); // warm off-white
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF2E2A26); // soft near-black

  /// Curated accent palette shown in Settings. Each is dark enough that white
  /// text/icons stay legible on filled buttons and the selected-tab pill.
  static const List<Color> accentOptions = [
    Color(0xFFF4683C), // coral (default)
    Color(0xFFE5484D), // red
    Color(0xFFF2820B), // amber
    Color(0xFF2F9E44), // green
    Color(0xFF0CA678), // teal
    Color(0xFF1C7ED6), // blue
    Color(0xFF7048E8), // violet
    Color(0xFFD6336C), // pink
  ];

  static ThemeData light([Color accent = defaultAccent]) {
    // primary == the chosen accent exactly, so `context.accent` is precise and
    // onPrimary stays white for legible filled buttons / the nav pill.
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      surface: surface,
      onSurface: ink,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3EEE8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Soft tag color for the gram-source "honesty" labels.
  static const Color tagBackground = Color(0xFFEFE7DD);
  static const Color tagText = Color(0xFF7A6A57);
}

/// The current accent color, read from the active theme so every widget that
/// uses it updates instantly when the user picks a new one in Settings.
extension AccentX on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
}
