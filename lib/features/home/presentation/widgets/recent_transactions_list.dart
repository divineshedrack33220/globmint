import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/services/mock_data.dart';

class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = MockData.transactions.take(5).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Activity',
          trailing: 'See All',
          onTrailingTap: () => context.go('/activity'),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: List.generate(transactions.length, (index) {
              final tx = transactions[index];
              return Column(
                children: [
                  _TransactionTile(transaction: tx),
                  if (index < transactions.length - 1)
                    const Divider(
                      height: 1,
                      indent: 68,
                      color: AppColors.divider,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final iconData = _getIcon();
    final iconColor = _getIconColor();
    final isPositive = transaction.type.name == 'deposit' ||
        (transaction.type.name == 'conversion' && transaction.toCurrency == 'USDT');

    return AnimatedPress(
      onTap: () => context.push('/activity/${transaction.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getIconBgColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.type.label,
                    style: context.typography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.description ?? transaction.destination ?? transaction.reference ?? '',
                    style: context.typography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isPositive
                      ? '+${CurrencyFormatter.ngn(transaction.amount)}'
                      : '-${CurrencyFormatter.ngn(transaction.amount)}',
                  style: context.typography.labelLarge.copyWith(
                    color: isPositive ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.relative(transaction.date),
                  style: context.typography.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return Icons.arrow_downward;
      case TransactionType.withdrawal:
        return Icons.arrow_upward;
      case TransactionType.conversion:
        return Icons.currency_exchange;
      case TransactionType.transfer:
        return Icons.send;
      case TransactionType.savings:
        return Icons.savings;
    }
  }

  Color _getIconColor() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return AppColors.success;
      case TransactionType.withdrawal:
        return AppColors.destructive;
      case TransactionType.conversion:
        return AppColors.primary;
      case TransactionType.transfer:
        return AppColors.info;
      case TransactionType.savings:
        return AppColors.primary;
    }
  }

  Color _getIconBgColor() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return AppColors.successMuted;
      case TransactionType.withdrawal:
        return AppColors.destructiveMuted;
      case TransactionType.conversion:
        return AppColors.primaryMuted;
      case TransactionType.transfer:
        return AppColors.infoMuted;
      case TransactionType.savings:
        return AppColors.primaryMuted;
    }
  }
}
