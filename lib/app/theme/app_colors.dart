import 'package:flutter/material.dart';

/// Raw color constants for the app's "energetic gym" design system. Not a
/// [ColorScheme] itself — [AppTheme] assembles those from these values so
/// every derived color (surfaces, containers, text-on-X) is defined in one
/// place per brightness.
abstract final class AppColors {
  // Shared accents — same hue in both themes, only their use as text-on-
  // light-background differs (see [darkColorScheme]/[lightColorScheme]).
  static const volt = Color(0xFFC6FF3D);
  static const ember = Color(0xFFFF7A1A);

  // Dark (default) theme.
  static const darkBackground = Color(0xFF0D0E11);
  static const darkSurface = Color(0xFF16181D);
  static const darkSurfaceContainer = Color(0xFF1E212A);
  static const darkInputFill = Color(0xFF262A35);
  static const darkOutline = Color(0xFF333845);
  static const darkOnSurface = Color(0xFFF2F3F5);
  static const darkOnSurfaceVariant = Color(0xFFA7ACB8);
  static const darkError = Color(0xFFFF4D4D);

  // Light theme.
  static const lightBackground = Color(0xFFF7F7F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceContainer = Color(0xFFF1F1EE);
  static const lightOutline = Color(0xFFDCDCD6);
  static const lightOnSurface = Color(0xFF14161A);
  static const lightOnSurfaceVariant = Color(0xFF5B606B);
  static const lightError = Color(0xFFD93025);
  // Volt/Ember deepened for use as text/icon-on-white — the raw accents
  // don't have enough contrast against a light background.
  static const voltOnLight = Color(0xFF5C7A00);
  static const emberOnLight = Color(0xFFD9600D);
}

ColorScheme buildDarkColorScheme() {
  return const ColorScheme.dark(
    primary: AppColors.volt,
    onPrimary: AppColors.darkBackground,
    secondary: AppColors.ember,
    onSecondary: AppColors.darkBackground,
    error: AppColors.darkError,
    onError: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    surfaceContainer: AppColors.darkSurfaceContainer,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutline,
  );
}

ColorScheme buildLightColorScheme() {
  return const ColorScheme.light(
    primary: AppColors.voltOnLight,
    onPrimary: AppColors.lightSurface,
    secondary: AppColors.emberOnLight,
    onSecondary: AppColors.lightSurface,
    error: AppColors.lightError,
    onError: AppColors.lightSurface,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    surfaceContainer: AppColors.lightSurfaceContainer,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutline,
  );
}
