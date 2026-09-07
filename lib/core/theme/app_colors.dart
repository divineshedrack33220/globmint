import 'package:flutter/material.dart';

abstract final class AppColors {
  // ============================================================
  // BACKGROUND LAYERS
  // ============================================================
  static const Color backgroundDeep = Color(0xFF000000);
  static const Color background = Color(0xFF080808);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF181818);
  static const Color surfaceHighlight = Color(0xFF202020);
  static const Color surfaceSoft = Color(0xFF0D0D0D);

  // ============================================================
  // BRAND — SIGNATURE YELLOW
  // ============================================================
  static const Color primary = Color(0xFFD6FB57);
  static const Color primaryBright = Color(0xFFD6FB57);
  static const Color primaryDark = Color(0xFFD6FB57);
  static const Color primaryMuted = Color(0xFFD6FB57);
  static const Color primaryGlow = Color(0x33D6FB57);
  static const Color primaryForeground = Color(0xFF000000);

  // ============================================================
  // TRANSPARENT / SUBTLE VARIANTS FOR HIGHLIGHTS & OVERLAYS
  // ============================================================
  static const Color primarySubtle = Color(0x4DD6FB57);   // 30% opacity for backgrounds
  static const Color primaryHighlight = Color(0x66D6FB57); // 40% for pressed/hover
  static const Color primaryOverlay = Color(0x1AD6FB57);  // 10% for subtle overlays
  static const Color primarySoft = Color(0x26D6FB57);     // 15% for very subtle

  // ============================================================
  // TEXT
  // ============================================================
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textTertiary = Color(0xFF737373);
  static const Color textDisabled = Color(0xFF4D4D4D);
  static const Color textOnPrimary = Color(0xFF000000);

  // ============================================================
  // FUNCTIONAL STATUS COLORS
  // ============================================================
  static const Color success = Color(0xFF22C55E);
  static const Color successMuted = Color(0xFF052E16);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningMuted = Color(0xFF451A03);

  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveMuted = Color(0xFF450A0A);

  static const Color info = Color(0xFF60A5FA);
  static const Color infoMuted = Color(0xFF172554);

  // ============================================================
  // BORDERS & DIVIDERS
  // ============================================================
  static const Color border = Color(0xFF242424);
  static const Color borderLight = Color(0xFF333333);
  static const Color borderSubtle = Color(0xFF1A1A1A);
  static const Color divider = Color(0xFF1C1C1C);

  // ============================================================
  // INPUTS
  // ============================================================
  static const Color inputBackground = Color(0xFF111111);
  static const Color inputFocus = Color(0xFF181818);
  static const Color inputBorder = Color(0xFF242424);
  static const Color inputBorderFocus = Color(0xFFD6FB57);
  static const Color inputBorderError = Color(0xFFEF4444);

  // ============================================================
  // OVERLAYS & LOADING
  // ============================================================
  static const Color overlay = Color(0xB3000000);
  static const Color skeletonBase = Color(0xFF181818);
  static const Color skeletonShimmer = Color(0xFF242424);
}
