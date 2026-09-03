import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/services/mock_data.dart';

class SavingsDetailsPage extends StatelessWidget {
  const SavingsDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final savings = MockData.savingsAccount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Savings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    Text('TOTAL SAVINGS', style: context.typography.labelMedium),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.usdt(savings.balance),
                      style: context.typography.amountHeroHighlight,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ ${CurrencyFormatter.ngn(savings.balance * (savings.exchangeRate ?? 0))}',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Add Money',
                      onPressed: () => context.push('/savings/add-money'),
                      variant: AppButtonVariant.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      text: 'Withdraw',
                      onPressed: () => context.push('/savings/withdraw'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('History', style: context.typography.title),
              const SizedBox(height: 12),
              // Full list
              ..._historyList(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _historyList(BuildContext context) {
    final txns = List<Transaction>.from(MockData.transactions)
        .where((t) => t.type.name == 'conversion' || t.type.name == 'savings')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (txns.isEmpty) {
      return [Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No savings activity', style: context.typography.bodyMedium)),
      )];
    }

    return txns.map((tx) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          onTap: () => context.push('/activity/${tx.id}'),
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.currency_exchange, color: AppColors.primary, size: 18),
          ),
          title: Text('Converted NGN → USDT', style: context.typography.labelLarge),
          subtitle: Text(DateFormatter.date(tx.date), style: context.typography.bodySmall),
          trailing: Text(
            CurrencyFormatter.usdt(tx.convertedAmount ?? tx.amount),
            style: context.typography.labelLarge.copyWith(color: AppColors.success),
          ),
        ),
      );
    }).toList();
  }
}
