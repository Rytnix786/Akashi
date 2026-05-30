/// Akashi Design System — Material Theme
/// Assembles colors + typography into a Flutter ThemeData.
library;

import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class AkashiTheme {
  AkashiTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AkashiColors.primary,
      onPrimary: AkashiColors.onPrimary,
      primaryContainer: AkashiColors.primaryContainer,
      onPrimaryContainer: AkashiColors.onPrimaryContainer,
      secondary: AkashiColors.secondary,
      onSecondary: AkashiColors.onSecondary,
      secondaryContainer: AkashiColors.secondaryContainer,
      onSecondaryContainer: AkashiColors.onSecondaryContainer,
      tertiary: AkashiColors.tertiary,
      onTertiary: AkashiColors.onTertiary,
      tertiaryContainer: AkashiColors.tertiaryContainer,
      onTertiaryContainer: AkashiColors.onTertiaryContainer,
      error: AkashiColors.error,
      onError: AkashiColors.onError,
      errorContainer: AkashiColors.errorContainer,
      onErrorContainer: AkashiColors.onErrorContainer,
      surface: AkashiColors.surface,
      onSurface: AkashiColors.onSurface,
      surfaceContainerHighest: AkashiColors.surfaceContainerHighest,
      onSurfaceVariant: AkashiColors.onSurfaceVariant,
      outline: AkashiColors.outline,
      outlineVariant: AkashiColors.outlineVariant,
      inverseSurface: AkashiColors.inverseSurface,
      onInverseSurface: AkashiColors.inverseOnSurface,
      inversePrimary: AkashiColors.inversePrimary,
      surfaceTint: AkashiColors.surfaceTint,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AkashiColors.background,
      fontFamily: AkashiTextTheme.fontFamily,

      // ─── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AkashiColors.surfaceContainerHigh,
        foregroundColor: AkashiColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AkashiTextTheme.headlineMd.copyWith(
          color: AkashiColors.primary,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AkashiColors.primary),
      ),

      // ─── Bottom Navigation ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AkashiColors.surfaceContainer,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AkashiColors.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AkashiColors.onPrimaryContainer);
          }
          return const IconThemeData(color: AkashiColors.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = AkashiTextTheme.labelLg;
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: AkashiColors.onPrimaryContainer);
          }
          return base.copyWith(color: AkashiColors.onSurfaceVariant);
        }),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ─── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AkashiColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: AkashiColors.outlineVariant,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Elevated Button ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AkashiColors.primary,
          foregroundColor: AkashiColors.onPrimary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: AkashiTextTheme.titleLg.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Filled Button ────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AkashiTextTheme.titleLg.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Input Fields ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AkashiColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AkashiColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AkashiColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AkashiColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AkashiColors.error),
        ),
        labelStyle: AkashiTextTheme.bodyLg.copyWith(
          color: AkashiColors.onSurfaceVariant,
        ),
        hintStyle: AkashiTextTheme.bodyLg.copyWith(
          color: AkashiColors.onSurfaceVariant,
        ),
      ),

      // ─── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AkashiColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ─── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ─── Text ─────────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AkashiTextTheme.headlineLg,
        displayMedium: AkashiTextTheme.headlineLgMobile,
        displaySmall: AkashiTextTheme.headlineMd,
        headlineLarge: AkashiTextTheme.headlineLg,
        headlineMedium: AkashiTextTheme.headlineLgMobile,
        headlineSmall: AkashiTextTheme.headlineMd,
        titleLarge: AkashiTextTheme.titleLg,
        titleMedium: AkashiTextTheme.bodyLg.copyWith(fontWeight: FontWeight.w600),
        titleSmall: AkashiTextTheme.bodyMd.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: AkashiTextTheme.bodyLg,
        bodyMedium: AkashiTextTheme.bodyMd,
        bodySmall: AkashiTextTheme.labelLg,
        labelLarge: AkashiTextTheme.labelLg,
        labelMedium: AkashiTextTheme.labelLg.copyWith(fontSize: 11),
        labelSmall: AkashiTextTheme.labelLg.copyWith(fontSize: 10),
      ),
    );
  }
}
