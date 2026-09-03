import 'package:flutter/material.dart';
import 'color_tokens.dart';
import 'typography_tokens.dart';
import 'spacing_tokens.dart';
import 'radius_tokens.dart';

extension BuildContextThemeExtensions on BuildContext {
  ColorTokens get colors => Theme.of(this).extension<ColorTokens>()!;
  TypographyTokens get typography => Theme.of(this).extension<TypographyTokens>()!;
  SpacingTokens get spacing => Theme.of(this).extension<SpacingTokens>()!;
}

abstract final class AppRadiusAccess {
  static double sm = AppRadius.sm;
  static double md = AppRadius.md;
  static double lg = AppRadius.lg;
  static double xl = AppRadius.xl;
  static double xxl = AppRadius.xxl;
}
