import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

@immutable
class TypographyTokens extends ThemeExtension<TypographyTokens> {
  const TypographyTokens({
    required this.amountHero,
    required this.amountHeroHighlight,
    required this.amountLarge,
    required this.amountMedium,
    required this.amountSmall,
    required this.display,
    required this.headline,
    required this.title,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  // Financial Display
  final TextStyle amountHero;
  final TextStyle amountHeroHighlight;
  final TextStyle amountLarge;
  final TextStyle amountMedium;
  final TextStyle amountSmall;

  // Headings
  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;

  // Body
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;

  // Labels
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;

  static TypographyTokens defaultTokens() {
    final inter = GoogleFonts.inter();
    final spaceGrotesk = GoogleFonts.spaceGrotesk();

    return TypographyTokens(
      amountHero: spaceGrotesk.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.1,
        letterSpacing: -0.8,
      ),
      amountHeroHighlight: spaceGrotesk.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
        height: 1.1,
        letterSpacing: -0.8,
      ),
      amountLarge: spaceGrotesk.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.1,
        letterSpacing: -0.5,
      ),
      amountMedium: inter.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      amountSmall: inter.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.3,
      ),
      display: spaceGrotesk.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      headline: inter.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      title: inter.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      bodyLarge: inter.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      bodyMedium: inter.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      bodySmall: inter.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.4,
      ),
      labelLarge: inter.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      labelMedium: inter.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      labelSmall: inter.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
        height: 1.4,
      ),
    );
  }

  @override
  TypographyTokens copyWith({
    TextStyle? amountHero,
    TextStyle? amountHeroHighlight,
    TextStyle? amountLarge,
    TextStyle? amountMedium,
    TextStyle? amountSmall,
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
  }) {
    return TypographyTokens(
      amountHero: amountHero ?? this.amountHero,
      amountHeroHighlight: amountHeroHighlight ?? this.amountHeroHighlight,
      amountLarge: amountLarge ?? this.amountLarge,
      amountMedium: amountMedium ?? this.amountMedium,
      amountSmall: amountSmall ?? this.amountSmall,
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      labelLarge: labelLarge ?? this.labelLarge,
      labelMedium: labelMedium ?? this.labelMedium,
      labelSmall: labelSmall ?? this.labelSmall,
    );
  }

  @override
  TypographyTokens lerp(ThemeExtension<TypographyTokens>? other, double t) {
    if (other is! TypographyTokens) return this;
    return TypographyTokens(
      amountHero: TextStyle.lerp(amountHero, other.amountHero, t)!,
      amountHeroHighlight: TextStyle.lerp(amountHeroHighlight, other.amountHeroHighlight, t)!,
      amountLarge: TextStyle.lerp(amountLarge, other.amountLarge, t)!,
      amountMedium: TextStyle.lerp(amountMedium, other.amountMedium, t)!,
      amountSmall: TextStyle.lerp(amountSmall, other.amountSmall, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      labelLarge: TextStyle.lerp(labelLarge, other.labelLarge, t)!,
      labelMedium: TextStyle.lerp(labelMedium, other.labelMedium, t)!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
    );
  }
}
