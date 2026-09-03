import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class ColorTokens extends ThemeExtension<ColorTokens> {
  const ColorTokens({
    required this.backgroundDeep,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHighlight,
    required this.surfaceSoft,
    required this.primary,
    required this.primaryBright,
    required this.primaryDark,
    required this.primaryMuted,
    required this.primaryForeground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnPrimary,
    required this.success,
    required this.successMuted,
    required this.warning,
    required this.warningMuted,
    required this.destructive,
    required this.destructiveMuted,
    required this.info,
    required this.infoMuted,
    required this.border,
    required this.borderLight,
    required this.borderSubtle,
    required this.divider,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputBorderFocus,
    required this.inputBorderError,
    required this.overlay,
    required this.skeletonBase,
    required this.skeletonShimmer,
  });

  // Background
  final Color backgroundDeep;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHighlight;
  final Color surfaceSoft;

  // Brand
  final Color primary;
  final Color primaryBright;
  final Color primaryDark;
  final Color primaryMuted;
  final Color primaryForeground;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textOnPrimary;

  // Status
  final Color success;
  final Color successMuted;
  final Color warning;
  final Color warningMuted;
  final Color destructive;
  final Color destructiveMuted;
  final Color info;
  final Color infoMuted;

  // Borders
  final Color border;
  final Color borderLight;
  final Color borderSubtle;
  final Color divider;

  // Inputs
  final Color inputBackground;
  final Color inputBorder;
  final Color inputBorderFocus;
  final Color inputBorderError;

  // Overlays
  final Color overlay;
  final Color skeletonBase;
  final Color skeletonShimmer;

  static ColorTokens get defaultTokens => const ColorTokens(
        backgroundDeep: AppColors.backgroundDeep,
        background: AppColors.background,
        surface: AppColors.surface,
        surfaceElevated: AppColors.surfaceElevated,
        surfaceHighlight: AppColors.surfaceHighlight,
        surfaceSoft: AppColors.surfaceSoft,
        primary: AppColors.primary,
        primaryBright: AppColors.primaryBright,
        primaryDark: AppColors.primaryDark,
        primaryMuted: AppColors.primaryMuted,
        primaryForeground: AppColors.primaryForeground,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        textTertiary: AppColors.textTertiary,
        textDisabled: AppColors.textDisabled,
        textOnPrimary: AppColors.textOnPrimary,
        success: AppColors.success,
        successMuted: AppColors.successMuted,
        warning: AppColors.warning,
        warningMuted: AppColors.warningMuted,
        destructive: AppColors.destructive,
        destructiveMuted: AppColors.destructiveMuted,
        info: AppColors.info,
        infoMuted: AppColors.infoMuted,
        border: AppColors.border,
        borderLight: AppColors.borderLight,
        borderSubtle: AppColors.borderSubtle,
        divider: AppColors.divider,
        inputBackground: AppColors.inputBackground,
        inputBorder: AppColors.inputBorder,
        inputBorderFocus: AppColors.inputBorderFocus,
        inputBorderError: AppColors.inputBorderError,
        overlay: AppColors.overlay,
        skeletonBase: AppColors.skeletonBase,
        skeletonShimmer: AppColors.skeletonShimmer,
      );

  @override
  ColorTokens copyWith({
    Color? backgroundDeep,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHighlight,
    Color? surfaceSoft,
    Color? primary,
    Color? primaryBright,
    Color? primaryDark,
    Color? primaryMuted,
    Color? primaryForeground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textOnPrimary,
    Color? success,
    Color? successMuted,
    Color? warning,
    Color? warningMuted,
    Color? destructive,
    Color? destructiveMuted,
    Color? info,
    Color? infoMuted,
    Color? border,
    Color? borderLight,
    Color? borderSubtle,
    Color? divider,
    Color? inputBackground,
    Color? inputBorder,
    Color? inputBorderFocus,
    Color? inputBorderError,
    Color? overlay,
    Color? skeletonBase,
    Color? skeletonShimmer,
  }) {
    return ColorTokens(
      backgroundDeep: backgroundDeep ?? this.backgroundDeep,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      primary: primary ?? this.primary,
      primaryBright: primaryBright ?? this.primaryBright,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      success: success ?? this.success,
      successMuted: successMuted ?? this.successMuted,
      warning: warning ?? this.warning,
      warningMuted: warningMuted ?? this.warningMuted,
      destructive: destructive ?? this.destructive,
      destructiveMuted: destructiveMuted ?? this.destructiveMuted,
      info: info ?? this.info,
      infoMuted: infoMuted ?? this.infoMuted,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      divider: divider ?? this.divider,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputBorderFocus: inputBorderFocus ?? this.inputBorderFocus,
      inputBorderError: inputBorderError ?? this.inputBorderError,
      overlay: overlay ?? this.overlay,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonShimmer: skeletonShimmer ?? this.skeletonShimmer,
    );
  }

  @override
  ColorTokens lerp(ThemeExtension<ColorTokens>? other, double t) {
    if (other is! ColorTokens) return this;
    return ColorTokens(
      backgroundDeep: Color.lerp(backgroundDeep, other.backgroundDeep, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHighlight: Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryBright: Color.lerp(primaryBright, other.primaryBright, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      primaryForeground: Color.lerp(primaryForeground, other.primaryForeground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      success: Color.lerp(success, other.success, t)!,
      successMuted: Color.lerp(successMuted, other.successMuted, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningMuted: Color.lerp(warningMuted, other.warningMuted, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveMuted: Color.lerp(destructiveMuted, other.destructiveMuted, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoMuted: Color.lerp(infoMuted, other.infoMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputBorderFocus: Color.lerp(inputBorderFocus, other.inputBorderFocus, t)!,
      inputBorderError: Color.lerp(inputBorderError, other.inputBorderError, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonShimmer: Color.lerp(skeletonShimmer, other.skeletonShimmer, t)!,
    );
  }
}
