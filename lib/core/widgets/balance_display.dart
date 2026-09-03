import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';

class BalanceDisplay extends StatelessWidget {
  const BalanceDisplay({
    super.key,
    required this.amount,
    this.label,
    this.currency = '₦',
    this.variant = BalanceVariant.large,
    this.color,
    this.showLabel = true,
    this.align = TextAlign.left,
  });

  final String amount;
  final String? label;
  final String currency;
  final BalanceVariant variant;
  final Color? color;
  final bool showLabel;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel && label != null)
          Text(
            label!,
            style: context.typography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: align,
          ),
        if (showLabel && label != null) const SizedBox(height: 4),
        Text(
          '$currency$amount',
          style: _getStyle(context).copyWith(color: color),
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  TextStyle _getStyle(BuildContext context) {
    switch (variant) {
      case BalanceVariant.hero:
        return context.typography.amountHero;
      case BalanceVariant.heroHighlight:
        return context.typography.amountHeroHighlight;
      case BalanceVariant.large:
        return context.typography.amountLarge;
      case BalanceVariant.medium:
        return context.typography.amountMedium;
      case BalanceVariant.small:
        return context.typography.amountSmall;
    }
  }
}

enum BalanceVariant { hero, heroHighlight, large, medium, small }
