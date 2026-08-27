import 'package:flutter/material.dart';

/// Builds the app's [TextTheme]: **Anton** (bold, condensed, poster-style)
/// for display/headline text — the "energetic gym" impact look — and
/// **Inter** (a variable font; Flutter picks the right weight from the one
/// bundled file via [FontWeight]) for everything read at body/label size.
/// Colored from [onSurface]/[onSurfaceVariant] so the same builder works for
/// both the dark and light theme.
TextTheme buildAppTextTheme({
  required Color onSurface,
  required Color onSurfaceVariant,
}) {
  TextStyle anton(double size, {double? height, double? letterSpacing}) {
    return TextStyle(
      fontFamily: 'Anton',
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: onSurface,
    );
  }

  TextStyle inter(
    double size,
    FontWeight weight, {
    double? height,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color ?? onSurface,
    );
  }

  return TextTheme(
    displayLarge: anton(48, height: 1.05, letterSpacing: 0.5),
    displayMedium: anton(38, height: 1.05, letterSpacing: 0.5),
    displaySmall: anton(30, height: 1.1, letterSpacing: 0.5),
    headlineLarge: anton(28, height: 1.1, letterSpacing: 0.5),
    headlineMedium: anton(24, height: 1.15, letterSpacing: 0.5),
    headlineSmall: anton(20, height: 1.2, letterSpacing: 0.5),
    titleLarge: inter(20, FontWeight.w700),
    titleMedium: inter(16, FontWeight.w600),
    titleSmall: inter(14, FontWeight.w600),
    bodyLarge: inter(16, FontWeight.w400),
    bodyMedium: inter(14, FontWeight.w400),
    bodySmall: inter(12, FontWeight.w400, color: onSurfaceVariant),
    labelLarge: inter(14, FontWeight.w600),
    labelMedium: inter(12, FontWeight.w600),
    labelSmall: inter(11, FontWeight.w600, color: onSurfaceVariant),
  );
}
