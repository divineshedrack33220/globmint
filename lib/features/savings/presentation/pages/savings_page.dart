import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/services/mock_data.dart';

class SavingsPage extends StatelessWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final savings = MockData.savingsAccount;
    final txns = List<Transaction>.from(MockData.transactions)
        .where((t) => t.type.name == 'conversion' || t.type.name == 'savings')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Savings', style: context.typography.display),
              const SizedBox(height: 20),
              // Savings Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAVINGS BALANCE',
                      style: context.typography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.ngn(savings.balance),
                      style: context.typography.amountHero,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ ${CurrencyFormatter.usdt(savings.usdtEquivalent ?? 0)} @ ₦${(savings.exchangeRate ?? 0).toStringAsFixed(2)}',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.add,
                      label: 'Add Money',
                      onTap: () => context.push('/savings/add-money'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.currency_exchange,
                      label: 'Convert',
                      onTap: () => context.push('/savings/convert'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.arrow_downward,
                      label: 'Withdraw',
                      onTap: () => context.push('/savings/withdraw'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Savings Activity', style: context.typography.title),
              const SizedBox(height: 12),
              if (txns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No savings activity yet',
                      style: context.typography.bodyMedium,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: List.generate(txns.take(8).length, (index) {
                      final tx = txns[index];
                      return Column(
                        children: [
                          _SavingTile(transaction: tx),
                          if (index < txns.take(8).length - 1)
                            const Divider(
                              height: 1,
                              indent: 64,
                              color: AppColors.divider,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(label, style: context.typography.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _SavingTile extends StatelessWidget {
  const _SavingTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isConversion = transaction.type.name == 'conversion';
    return ListTile(
      onTap: () => context.push('/activity/${transaction.id}'),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isConversion ? Icons.currency_exchange : Icons.savings,
          color: AppColors.primary,
          size: 18,
        ),
      ),
      title: Text(
        isConversion ? 'Converted NGN → USDT' : 'Savings deposit',
        style: context.typography.labelLarge,
      ),
      subtitle: Text(
        DateFormatter.date(transaction.date),
        style: context.typography.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isConversion
                ? CurrencyFormatter.usdt(transaction.convertedAmount ?? transaction.amount)
                : CurrencyFormatter.usdt(transaction.amount),
            style: context.typography.labelLarge.copyWith(
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 2),
          StatusBadge(status: transaction.status, size: StatusBadgeSize.small),
        ],
      ),
    );
  }
}
