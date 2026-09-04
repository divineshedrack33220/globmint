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
          Text('Savings Overview', style: context.typography.title),
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
        ],
      ),
    );
  }
}
