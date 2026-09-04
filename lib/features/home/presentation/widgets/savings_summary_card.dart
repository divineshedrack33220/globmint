import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/account.dart';

class SavingsSummaryCard extends StatelessWidget {
  const SavingsSummaryCard({super.key, required this.summaryAsync});

  final AsyncValue<AccountSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final savings = summary?.savings;
    final ngnValue = summary?.totalUsdtEquivalent != null
        ? summary!.totalUsdtEquivalent * (summary.currentRate == 0 ? 1604.5 : summary.currentRate)
        : 0.0;
    final usdtValue = savings?.balance ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Savings Overview', style: context.typography.title),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '+4.2%',
                      style: context.typography.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Savings Value', style: context.typography.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.ngn(ngnValue),
                      style: context.typography.amountMedium,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.border,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('USDT Equivalent', style: context.typography.labelMedium),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.usdt(usdtValue),
                        style: context.typography.amountMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Goal Progress', style: context.typography.labelMedium),
                  Text(
                    '--%',
                    style: context.typography.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.0,
                  backgroundColor: AppColors.surfaceHighlight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
