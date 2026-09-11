import 'package:flutter/material.dart';

/// Red Hat's brand red, used as the seed so the app reads as RHCSA study
/// material at a glance.
const _seed = Color(0xFFEE0000);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      side: BorderSide.none,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

/// Monospace styling for commands, paths, and option text that quotes shell
/// syntax — the distinction matters constantly in this material.
const kMono = TextStyle(fontFamily: 'monospace', fontFamilyFallback: [
  'DejaVu Sans Mono',
  'Roboto Mono',
  'Menlo',
  'Courier New',
]);

/// Semantic colors for right/wrong that survive both brightness modes.
class ResultColors {
  static Color correct(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF5CD68A)
          : const Color(0xFF1E7A45);

  static Color wrong(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFFFF8A80)
          : const Color(0xFFB3261E);
}
