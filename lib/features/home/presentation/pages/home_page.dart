import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/account.dart';
import '../../../../shared/models/models.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/savings_summary_card.dart';
import '../widgets/recent_transactions_list.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final userAsync = ref.watch(currentUserProvider);

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
                      userAsync.maybeWhen(
                        data: (u) => u.firstName,
                        orElse: () => '...',
                      ),
                      style: context.typography.headline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Balance hero / loading / error
              summaryAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _BalanceSkeleton(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: BalanceCard(
                    label: 'TOTAL SAVINGS',
                    amount: '₦0.00',
                    subtitle: 'Unable to load balance',
                    isHero: true,
                  ),
                ),
                data: (summary) => _BalanceSection(summary: summary),
              ),
              const SizedBox(height: 16),
              // Available Balance
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _AvailableBalanceCard(summaryAsync: summaryAsync),
              ),
              const SizedBox(height: 24),
              // Quick Actions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: QuickActionsRow(),
              ),
              const SizedBox(height: 24),
              // Savings Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SavingsSummaryCard(summaryAsync: summaryAsync),
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

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({required this.summary});
  final AccountSummary summary;

  @override
  Widget build(BuildContext context) {
    return BalanceCard(
      label: 'TOTAL SAVINGS',
      amount: CurrencyFormatter.ngn(summary.totalNgnEquivalent),
      subtitle: '≈ ${CurrencyFormatter.usdt(summary.totalUsdtEquivalent)}',
      isHero: true,
    );
  }
}

class _AvailableBalanceCard extends StatelessWidget {
  const _AvailableBalanceCard({required this.summaryAsync});
  final AsyncValue<AccountSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final available = summary?.available;
    final currentRate = summary?.currentRate ?? 0;

    return Container(
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
              Text('Available Balance', style: context.typography.labelMedium),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.ngn(available?.balance ?? 0),
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
              Text('Exchange Rate', style: context.typography.labelMedium),
              const SizedBox(height: 4),
              Text(
                '₦${currentRate.toStringAsFixed(2)}',
                style: context.typography.amountMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
