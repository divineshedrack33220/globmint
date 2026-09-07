import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../shared/models/transaction.dart';

class RecentTransactionsList extends ConsumerWidget {
  const RecentTransactionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Activity',
          trailing: 'See All',
          onTrailingTap: () => context.go('/activity'),
        ),
        const SizedBox(height: 12),
        transactionsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (_, _) => const SizedBox(
            height: 80,
            child: Center(child: Text('Unable to load transactions')),
          ),
          data: (transactions) {
            final sorted = List<Transaction>.from(transactions)
              ..sort((a, b) => b.date.compareTo(a.date));
            if (sorted.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No recent activity',
                description: 'Your transactions will appear here',
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                children: List.generate(sorted.length, (index) {
                  final tx = sorted[index];
                  return Column(
                    children: [
                      _TransactionTile(transaction: tx),
                      if (index < sorted.length - 1)
                        const Divider(
                          height: 1,
                          indent: 68,
                          color: AppColors.divider,
                        ),
                    ],
                  );
                }),
              ),
            );
          },
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
      case TransactionType.fee:
        return Icons.receipt;
      case TransactionType.adjustment:
        return Icons.tune;
      case TransactionType.reversal:
        return Icons.swap_horiz;
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
      case TransactionType.fee:
        return AppColors.warning;
      case TransactionType.adjustment:
        return AppColors.info;
      case TransactionType.reversal:
        return AppColors.destructive;
    }
  }

  Color _getIconBgColor() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return AppColors.successMuted;
      case TransactionType.withdrawal:
        return AppColors.destructiveMuted;
      case TransactionType.conversion:
        return AppColors.primarySubtle;
      case TransactionType.transfer:
        return AppColors.infoMuted;
      case TransactionType.savings:
        return AppColors.primarySubtle;
      case TransactionType.fee:
        return AppColors.warningMuted;
      case TransactionType.adjustment:
        return AppColors.infoMuted;
      case TransactionType.reversal:
        return AppColors.destructiveMuted;
    }
  }
}
