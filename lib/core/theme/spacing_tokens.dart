import 'dart:ui';
import 'package:flutter/material.dart';

@immutable
class SpacingTokens extends ThemeExtension<SpacingTokens> {
  const SpacingTokens({
    this.xxs = 2,
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 20,
    this.xxl = 24,
    this.xxxl = 32,
    this.x4xl = 40,
    this.x5xl = 48,
    this.x6xl = 64,
  });

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double x4xl;
  final double x5xl;
  final double x6xl;

  static const SpacingTokens defaultTokens = SpacingTokens();

  @override
  SpacingTokens copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? xxxl,
    double? x4xl,
    double? x5xl,
    double? x6xl,
  }) {
    return SpacingTokens(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      xxxl: xxxl ?? this.xxxl,
      x4xl: x4xl ?? this.x4xl,
      x5xl: x5xl ?? this.x5xl,
      x6xl: x6xl ?? this.x6xl,
    );
  }

  @override
  SpacingTokens lerp(ThemeExtension<SpacingTokens>? other, double t) {
    if (other is! SpacingTokens) return this;
    return SpacingTokens(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
      xxxl: lerpDouble(xxxl, other.xxxl, t)!,
      x4xl: lerpDouble(x4xl, other.x4xl, t)!,
      x5xl: lerpDouble(x5xl, other.x5xl, t)!,
      x6xl: lerpDouble(x6xl, other.x6xl, t)!,
    );
  }
}
