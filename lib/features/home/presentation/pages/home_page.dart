import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/mock_data.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/savings_summary_card.dart';
import '../widgets/recent_transactions_list.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = MockData.accountSummary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: context.typography.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MockData.user.firstName,
                      style: context.typography.headline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Total Balance Hero
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BalanceCard(
                  label: 'TOTAL SAVINGS',
                  amount: CurrencyFormatter.ngn(summary.totalNgnEquivalent),
                  subtitle: '≈ ${CurrencyFormatter.usdt(summary.totalUsdtEquivalent)}',
                  isHero: true,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+4.2%',
                      style: context.typography.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Available Balance
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Balance',
                            style: context.typography.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.ngn(summary.available.balance),
                            style: context.typography.amountMedium,
                          ),
                        ],
                      ),
                      Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exchange Rate',
                            style: context.typography.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₦${summary.currentRate.toStringAsFixed(2)}',
                            style: context.typography.amountMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Quick Actions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: QuickActionsRow(),
              ),
              const SizedBox(height: 24),
              // Savings Summary
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SavingsSummaryCard(),
              ),
              const SizedBox(height: 24),
              // Recent Transactions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: RecentTransactionsList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
