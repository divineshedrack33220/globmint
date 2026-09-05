import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/radius_tokens.dart';
import '../theme/theme_extensions.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.elevated = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? (elevated ? AppColors.surfaceElevated : AppColors.surface);
    final border = borderColor ?? AppColors.border;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: border, width: 1),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.label,
    required this.amount,
    this.amountColor,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    this.isHero = false,
  });

  final String label;
  final String amount;
  final Color? amountColor;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: context.typography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: isHero ? 12 : 8),
          Text(
            amount,
            style: isHero
                ? context.typography.amountHero
                : context.typography.amountLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: context.typography.bodySmall.copyWith(
                color: amountColor ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
