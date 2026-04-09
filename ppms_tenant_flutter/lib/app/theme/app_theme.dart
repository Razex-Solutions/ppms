import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme(Locale locale) {
  const colorScheme = ColorScheme.light(
    primary: Color(0xFF0B6E4F),
    onPrimary: Colors.white,
    secondary: Color(0xFFE3B23C),
    onSecondary: Color(0xFF1F2933),
    surface: Color(0xFFF7F3EA),
    onSurface: Color(0xFF172026),
    error: Color(0xFFB42318),
    onError: Colors.white,
  );

  final baseTheme = ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF1ECE2),
    useMaterial3: true,
  );

  final textTheme = locale.languageCode == 'ur'
      ? GoogleFonts.notoNaskhArabicTextTheme(baseTheme.textTheme)
      : GoogleFonts.sourceSans3TextTheme(baseTheme.textTheme);

  return baseTheme.copyWith(
    textTheme: textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE6DED0)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD5CBB8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD5CBB8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
  );
}
