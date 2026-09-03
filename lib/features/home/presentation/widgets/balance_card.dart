import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.label,
    required this.amount,
    this.amountColor,
    this.subtitle,
    this.trailing,
    this.isHero = false,
  });

  final String label;
  final String amount;
  final Color? amountColor;
  final String? subtitle;
  final Widget? trailing;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
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
