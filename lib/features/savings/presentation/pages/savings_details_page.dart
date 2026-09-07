import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/savings_client.dart';

class SavingsDetailsPage extends ConsumerWidget {
  const SavingsDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final depositAsync = ref.watch(depositInfoProvider);

    final txns = (txnsAsync.valueOrNull ?? const <Transaction>[])
        .where((t) =>
            t.type == TransactionType.conversion ||
            t.type == TransactionType.savings ||
            t.type == TransactionType.deposit ||
            t.type == TransactionType.withdrawal)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Savings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              _depositInfoCard(context, depositAsync),
              const SizedBox(height: 24),
              Text('History', style: context.typography.title),
              const SizedBox(height: 12),
              if (txnsAsync.isLoading && !txnsAsync.hasValue)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                ..._historyList(context, txns, txnsAsync.hasError),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _depositInfoCard(
    BuildContext context,
    AsyncValue<DepositInfo> depositAsync,
  ) {
    final deposit = depositAsync.valueOrNull;
    final loading = depositAsync.isLoading && !depositAsync.hasValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Deposit Address', style: context.typography.title),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (deposit == null)
            Text(
              'Unable to load deposit details.',
              style: context.typography.bodyMedium,
            )
          else ...[
            _detailRow(context, 'Network', deposit.network),
            _detailRow(context, 'Chain ID', '${deposit.chainId}'),
            _detailRow(
                context, 'Asset', '${deposit.stablecoinSymbol} · ${deposit.stablecoinName}'),
            const Divider(height: 20, color: AppColors.border),
            if (deposit.vaultContract.isNotEmpty)
              _detailRow(
                context,
                'Vault contract (send asset to this address)',
                deposit.vaultContract,
                highlight: true,
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Link your own wallet below — you fund savings by sending USDC on ${deposit.network}.',
                  style: context.typography.bodySmall,
                ),
              ),
            if (deposit.hasAddress) ...[
              const SizedBox(height: 8),
              _detailRow(context, 'Your linked wallet', deposit.address),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Link your wallet address to receive on-chain deposits.',
                  style: context.typography.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.typography.bodySmall),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: context.typography.labelLarge.copyWith(
              color: highlight
                  ? AppColors.primary
                  : (value.isEmpty ? AppColors.textTertiary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _historyList(
    BuildContext context,
    List<Transaction> txns,
    bool hasError,
  ) {
    if (txns.isEmpty) {
      return [Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            hasError ? 'Could not load activity' : 'No savings activity',
            style: context.typography.bodyMedium,
          ),
        ),
      )];
    }

    return txns.map((tx) {
      final IconData icon;
      final String title;
      final String amountText;
      switch (tx.type) {
        case TransactionType.deposit:
          icon = Icons.arrow_downward;
          title = 'Vault deposit';
          amountText = '+${_money(tx.amount, tx.currency)}';
        case TransactionType.withdrawal:
          icon = Icons.arrow_upward;
          title = 'Vault withdrawal';
          amountText = '−${_money(tx.amount, tx.currency)}';
        case TransactionType.conversion:
          icon = Icons.currency_exchange;
          final from =
              (tx.fromCurrency?.isNotEmpty ?? false) ? tx.fromCurrency! : '—';
          final to =
              (tx.toCurrency?.isNotEmpty ?? false) ? tx.toCurrency! : '—';
          title = 'Converted $from → $to';
          amountText = _money(tx.convertedAmount ?? tx.amount,
              to == '—' ? tx.currency : to);
        case TransactionType.savings:
        default:
          icon = Icons.savings;
          title = 'Savings move';
          amountText = _money(tx.amount, tx.currency);
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          onTap: () => context.push('/activity/${tx.id}'),
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          title: Text(title, style: context.typography.labelLarge),
          subtitle: Text(DateFormatter.date(tx.date),
              style: context.typography.bodySmall),
          trailing: Text(
            amountText,
            style: context.typography.labelLarge.copyWith(
              color: AppColors.success,
            ),
          ),
        ),
      );
    }).toList();
  }

  String _money(double amount, String currency) {
    if (currency == 'NGN') return CurrencyFormatter.ngn(amount);
    return '${amount.toStringAsFixed(2)} $currency';
  }
}
