/// Akashi Design System — Colors
/// Source: Stitch design (DESIGN.md) — Material Design 3 Tonal Palette
/// All colors match exactly the Stitch-generated HTML code.html files.
library;

import 'package:flutter/material.dart';

class AkashiColors {
  AkashiColors._();

  // ─── Primary — Deep Agricultural Green ──────────────────────────────────
  static const Color primary = Color(0xFF00450D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1B5E20);
  static const Color onPrimaryContainer = Color(0xFF90D689);
  static const Color inversePrimary = Color(0xFF91D78A);
  static const Color primaryFixed = Color(0xFFACF4A4);
  static const Color primaryFixedDim = Color(0xFF91D78A);
  static const Color onPrimaryFixed = Color(0xFF002203);
  static const Color onPrimaryFixedVariant = Color(0xFF0C5216);
  static const Color surfaceTint = Color(0xFF2A6B2C);

  // ─── Secondary — Sky Blue (satellite/weather) ────────────────────────────
  static const Color secondary = Color(0xFF00639A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF51B2FE);
  static const Color onSecondaryContainer = Color(0xFF00436A);
  static const Color secondaryFixed = Color(0xFFCEE5FF);
  static const Color secondaryFixedDim = Color(0xFF96CCFF);
  static const Color onSecondaryFixed = Color(0xFF001D32);
  static const Color onSecondaryFixedVariant = Color(0xFF004A75);

  // ─── Tertiary — Golden Rice Yellow (alerts, harvest) ─────────────────────
  static const Color tertiary = Color(0xFF4C3700);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF694D00);
  static const Color onTertiaryContainer = Color(0xFFF6BC28);
  static const Color tertiaryFixed = Color(0xFFFFDFA0);
  static const Color tertiaryFixedDim = Color(0xFFF8BD2A);
  static const Color onTertiaryFixed = Color(0xFF261A00);
  static const Color onTertiaryFixedVariant = Color(0xFF5C4300);

  // ─── Error ──────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ─── Surface & Background ────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FF);
  static const Color onBackground = Color(0xFF171C22);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color onSurface = Color(0xFF171C22);
  static const Color surfaceDim = Color(0xFFD6DAE3);
  static const Color surfaceBright = Color(0xFFF8F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F4FD);
  static const Color surfaceContainer = Color(0xFFEAEEF7);
  static const Color surfaceContainerHigh = Color(0xFFE4E8F1);
  static const Color surfaceContainerHighest = Color(0xFFDEE3EB);
  static const Color surfaceVariant = Color(0xFFDEE3EB);
  static const Color onSurfaceVariant = Color(0xFF41493E);
  static const Color inverseSurface = Color(0xFF2C3137);
  static const Color inverseOnSurface = Color(0xFFEDF1FA);

  // ─── Outline ────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF717A6D);
  static const Color outlineVariant = Color(0xFFC0C9BB);

  // ─── Semantic Health Colors ──────────────────────────────────────────────
  static const Color healthGreen = Color(0xFF1B5E20);
  static const Color healthGreenLight = Color(0xFFACF4A4);
  static const Color healthYellow = Color(0xFF694D00);
  static const Color healthYellowLight = Color(0xFFFFDFA0);
  static const Color healthRed = Color(0xFFBA1A1A);
  static const Color healthRedLight = Color(0xFFFFDAD6);

  /// Returns the background color for a health status card.
  static Color healthCardBackground(String status) {
    switch (status) {
      case 'green':
        return primaryFixed; // #ACF4A4
      case 'yellow':
        return tertiaryFixed; // #FFDFA0
      case 'red':
        return errorContainer; // #FFDAD6
      default:
        return surfaceContainer;
    }
  }

  /// Returns the text color for a health status card.
  static Color healthCardText(String status) {
    switch (status) {
      case 'green':
        return onPrimaryFixed; // #002203
      case 'yellow':
        return onTertiaryFixed; // #261A00
      case 'red':
        return onErrorContainer; // #93000A
      default:
        return onSurface;
    }
  }

  /// Returns the accent/border color for a health status.
  static Color healthAccent(String status) {
    switch (status) {
      case 'green':
        return primary;
      case 'yellow':
        return tertiaryContainer;
      case 'red':
        return error;
      default:
        return outline;
    }
  }
}
