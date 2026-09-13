import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/shimmer.dart';
import '../../../../core/widgets/transaction_style.dart';
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
          loading: () => const TransactionListSkeleton(tiles: 5),
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
    final (iconData, iconColor, iconBg) = transactionStyle(transaction.type);
    final isPositive =
        transaction.type.name == 'deposit' ||
        (transaction.type.name == 'conversion' &&
            transaction.toCurrency == 'USDT');

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
                color: iconBg,
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
                    transaction.description ??
                        transaction.destination ??
                        transaction.reference ??
                        '',
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
                    color: isPositive
                        ? AppColors.success
                        : AppColors.textPrimary,
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
}
