import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../shared/models/transaction.dart';

enum _ActivityFilter { all, deposits, withdrawals, transfers, conversions }

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  _ActivityFilter _filter = _ActivityFilter.all;

  String get _filterLabel => switch (_filter) {
        _ActivityFilter.all => 'All',
        _ActivityFilter.deposits => 'Deposits',
        _ActivityFilter.withdrawals => 'Withdrawals',
        _ActivityFilter.transfers => 'Transfers',
        _ActivityFilter.conversions => 'Conversions',
      };

  List<Transaction> _applyFilter(List<Transaction> transactions) {
    switch (_filter) {
      case _ActivityFilter.all:
        return transactions;
      case _ActivityFilter.deposits:
        return transactions.where((t) => t.type == TransactionType.deposit).toList();
      case _ActivityFilter.withdrawals:
        return transactions.where((t) => t.type == TransactionType.withdrawal).toList();
      case _ActivityFilter.transfers:
        return transactions.where((t) => t.type == TransactionType.transfer).toList();
      case _ActivityFilter.conversions:
        return transactions
            .where((t) =>
                t.type == TransactionType.conversion ||
                t.type == TransactionType.savings)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text('Activity', style: context.typography.display),
            ),
            const SizedBox(height: 16),
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _filter == _ActivityFilter.all,
                      onTap: () => setState(() => _filter = _ActivityFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Deposits',
                      isSelected: _filter == _ActivityFilter.deposits,
                      onTap: () => setState(() => _filter = _ActivityFilter.deposits),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Withdrawals',
                      isSelected: _filter == _ActivityFilter.withdrawals,
                      onTap: () => setState(() => _filter = _ActivityFilter.withdrawals),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Transfers',
                      isSelected: _filter == _ActivityFilter.transfers,
                      onTap: () => setState(() => _filter = _ActivityFilter.transfers),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Conversions',
                      isSelected: _filter == _ActivityFilter.conversions,
                      onTap: () => setState(() => _filter = _ActivityFilter.conversions),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Transaction list
            Expanded(
              child: transactionsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, _) => Center(
                  child: Text(
                    'Unable to load transactions',
                    style: context.typography.bodyMedium,
                  ),
                ),
                data: (txns) {
                  final sorted = List<Transaction>.from(txns)
                    ..sort((a, b) => b.date.compareTo(a.date));
                  final transactions = _applyFilter(sorted);
                  if (transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primaryMuted,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text('No $_filterLabel activity', style: context.typography.headline),
                          const SizedBox(height: 8),
                          Text(
                            'Transactions in this category will appear here',
                            style: context.typography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: ListView.separated(
                      key: ValueKey(_filter),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 68,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return _TransactionTile(transaction: tx);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: context.typography.labelMedium.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.type == TransactionType.deposit;

    return AnimatedPress(
      onTap: () => context.push('/activity/${transaction.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getIconBgColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getIcon(), color: _getIconColor(), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.type.label,
                    style: context.typography.labelLarge,
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
        return AppColors.primaryMuted;
      case TransactionType.transfer:
        return AppColors.infoMuted;
      case TransactionType.savings:
        return AppColors.primaryMuted;
      case TransactionType.fee:
        return AppColors.warningMuted;
      case TransactionType.adjustment:
        return AppColors.infoMuted;
      case TransactionType.reversal:
        return AppColors.destructiveMuted;
    }
  }
}
