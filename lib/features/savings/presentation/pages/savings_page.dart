import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/services/savings_client.dart';

class SavingsPage extends ConsumerStatefulWidget {
  const SavingsPage({super.key});

  @override
  ConsumerState<SavingsPage> createState() => _SavingsPageState();
}

enum _ActivityFilter { all, deposits, withdrawals, conversions, moves }

class _SavingsPageState extends ConsumerState<SavingsPage> {
  _ActivityFilter _filter = _ActivityFilter.all;

  bool _visible(TransactionType type) {
    if (!(type == TransactionType.deposit ||
        type == TransactionType.withdrawal ||
        type == TransactionType.conversion ||
        type == TransactionType.savings)) {
      return false;
    }
    return switch (_filter) {
      _ActivityFilter.all => true,
      _ActivityFilter.deposits => type == TransactionType.deposit,
      _ActivityFilter.withdrawals => type == TransactionType.withdrawal,
      _ActivityFilter.conversions => type == TransactionType.conversion,
      _ActivityFilter.moves => type == TransactionType.savings,
    };
  }

  /// "Daily limit ₦X of ₦Y used • Time-lock above ₦Z", or null when the
  /// server configures no guards. Usage is summed client-side from today's
  /// withdrawals (UTC day, matching the server).
  String? _limitsLine(VaultStatus? status, List<Transaction> allTxns) {
    if (status == null) return null;
    final parts = <String>[];
    if (status.withdrawDailyCapMinor > 0) {
      final now = DateTime.now().toUtc();
      var usedMinor = 0;
      for (final t in allTxns) {
        if (t.type != TransactionType.withdrawal) continue;
        final d = t.date.toUtc();
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          usedMinor += (t.amount * 100).round();
        }
      }
      parts.add(
          'Daily limit ${CurrencyFormatter.ngn(usedMinor / 100)} of ${CurrencyFormatter.ngn(status.withdrawDailyCapMinor / 100)} used');
    }
    if (status.elevationThresholdMinor > 0) {
      parts.add(
          'Time-lock above ${CurrencyFormatter.ngn(status.elevationThresholdMinor / 100)}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(transactionsProvider);
    final allTxns = txnsAsync.valueOrNull ?? const <Transaction>[];
    final txns = List<Transaction>.from(allTxns)
        .where((t) => _visible(t.type))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final limits =
        _limitsLine(ref.watch(vaultStatusProvider).valueOrNull, allTxns);

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
                      icon: Icons.bookmark_outline,
                      label: 'Saved Addresses',
                      onTap: () => context.push('/profile/beneficiaries'),
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
              if (limits != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Text(
                      limits,
                      textAlign: TextAlign.center,
                      style: context.typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              Text('Savings Activity', style: context.typography.title),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == _ActivityFilter.all,
                      onTap: () => setState(
                          () => _filter = _ActivityFilter.all),
                    ),
                    _FilterChip(
                      label: 'Deposits',
                      selected: _filter == _ActivityFilter.deposits,
                      onTap: () => setState(
                          () => _filter = _ActivityFilter.deposits),
                    ),
                    _FilterChip(
                      label: 'Withdrawals',
                      selected: _filter == _ActivityFilter.withdrawals,
                      onTap: () => setState(
                          () => _filter = _ActivityFilter.withdrawals),
                    ),
                    _FilterChip(
                      label: 'Conversions',
                      selected: _filter == _ActivityFilter.conversions,
                      onTap: () => setState(
                          () => _filter = _ActivityFilter.conversions),
                    ),
                    _FilterChip(
                      label: 'Moves',
                      selected: _filter == _ActivityFilter.moves,
                      onTap: () => setState(
                          () => _filter = _ActivityFilter.moves),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (txns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: _filter == _ActivityFilter.all
                        ? Icons.savings_outlined
                        : Icons.filter_list_off,
                    title: 'No savings activity yet',
                    description: _filter == _ActivityFilter.all
                        ? 'Deposits, withdrawals and conversions will appear here'
                        : 'Nothing here yet in this category',
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
              if (txns.length > 8) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/activity'),
                    child: Text(
                      'See all activity',
                      style: context.typography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySubtle : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: context.typography.labelMedium.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
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

  String _formatMoney(double amount, String currency) {
    if (currency == 'NGN') return CurrencyFormatter.ngn(amount);
    return '${amount.toStringAsFixed(2)} $currency';
  }

  String _shortAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final IconData icon;
    final Color color;
    final String title;
    final String amountText;
    switch (tx.type) {
      case TransactionType.deposit:
        icon = Icons.arrow_downward;
        color = AppColors.success;
        title = 'Vault deposit';
        amountText = '+${_formatMoney(tx.amount, tx.currency)}';
      case TransactionType.withdrawal:
        icon = Icons.arrow_upward;
        color = AppColors.destructive;
        title = 'Vault withdrawal';
        amountText = '−${_formatMoney(tx.amount, tx.currency)}';
      case TransactionType.conversion:
        icon = Icons.currency_exchange;
        color = AppColors.primary;
        final from = (tx.fromCurrency?.isNotEmpty ?? false) ? tx.fromCurrency! : '—';
        final to = (tx.toCurrency?.isNotEmpty ?? false) ? tx.toCurrency! : '—';
        title = 'Converted $from → $to';
        amountText = _formatMoney(tx.convertedAmount ?? tx.amount, to == '—' ? tx.currency : to);
      case TransactionType.savings:
      default:
        icon = Icons.savings;
        color = AppColors.primary;
        title = 'Savings move';
        amountText = _formatMoney(tx.amount, tx.currency);
    }
    final subtitle = tx.type == TransactionType.withdrawal &&
            (tx.destination?.isNotEmpty ?? false)
        ? '${DateFormatter.date(tx.date)} • to ${_shortAddress(tx.destination!)}'
        : DateFormatter.date(tx.date);

    return ListTile(
      onTap: () => context.push('/activity/${transaction.id}'),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primarySubtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: context.typography.labelLarge),
      subtitle: Text(subtitle, style: context.typography.bodySmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amountText,
            style: context.typography.labelLarge.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          StatusBadge(status: transaction.status, size: StatusBadgeSize.small),
        ],
      ),
    );
  }
}
