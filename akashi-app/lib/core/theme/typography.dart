/// Akashi Design System — Typography
/// Source: Stitch DESIGN.md — Noto Sans + Noto Sans Bengali
/// Bengali line-height is 1.2x standard Latin as per design spec.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AkashiTextTheme {
  AkashiTextTheme._();

  // ─── Font Family ──────────────────────────────────────────────────────────
  // Noto Sans Bengali supports both Bengali and Latin scripts seamlessly.
  // System falls back gracefully if Google Fonts unavailable offline.
  static String get fontFamily => 'NotoSansBengali';

  // ─── Type Scale (from DESIGN.md) ─────────────────────────────────────────
  // headline-lg:        32px / 700 / lh:40px
  // headline-lg-mobile: 28px / 700 / lh:36px
  // headline-md:        24px / 600 / lh:32px
  // title-lg:           20px / 600 / lh:28px
  // body-lg:            16px / 400 / lh:24px
  // body-md:            14px / 400 / lh:20px
  // label-lg:           12px / 500 / lh:16px / ls:0.5px

  static TextStyle headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: 0,
    color: AkashiColors.onSurface,
  );

  static TextStyle headlineLgMobile = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 36 / 28,
    color: AkashiColors.onSurface,
  );

  static TextStyle headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: AkashiColors.onSurface,
  );

  static TextStyle titleLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    color: AkashiColors.onSurface,
  );

  static TextStyle bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AkashiColors.onSurface,
  );

  static TextStyle bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AkashiColors.onSurface,
  );

  static TextStyle labelLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.5,
    color: AkashiColors.onSurface,
  );

  // ─── Convenience — colored variants ───────────────────────────────────────
  static TextStyle bodyLgMuted = bodyLg.copyWith(
    color: AkashiColors.onSurfaceVariant,
  );

  static TextStyle bodyMdMuted = bodyMd.copyWith(
    color: AkashiColors.onSurfaceVariant,
  );

  static TextStyle labelLgMuted = labelLg.copyWith(
    color: AkashiColors.onSurfaceVariant,
  );

  static TextStyle labelLgUppercase = labelLg.copyWith(
    color: AkashiColors.onSurfaceVariant,
    letterSpacing: 1.0,
  );

  static TextStyle primaryHeadline = headlineLgMobile.copyWith(
    color: AkashiColors.primary,
  );
}
