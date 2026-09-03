import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/enums/transaction_status.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/services/mock_data.dart';

class TransactionDetailsPage extends StatelessWidget {
  const TransactionDetailsPage({super.key, this.transactionId});

  final String? transactionId;

  @override
  Widget build(BuildContext context) {
    final txn = MockData.transactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => MockData.transactions.isNotEmpty ? MockData.transactions.first : Transaction(
        id: 'none', type: TransactionType.transfer, amount: 0, currency: 'NGN',
        status: TransactionStatus.failed, date: DateTime.now(),
      ),
    );

    final isPositive = txn.isPositive;
    final amountStyle = isPositive ? Icons.arrow_downward : Icons.arrow_upward;
    final amountColor = isPositive ? AppColors.success : AppColors.destructive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Transaction Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(amountStyle, color: amountColor, size: 20),
                        const SizedBox(width: 6),
                        Text(txn.type.label, style: context.typography.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${txn.currency == 'USDT' ? 'USDT ' : '₦'}${txn.currency == 'USDT' ? CurrencyFormatter.usdt(txn.amount) : CurrencyFormatter.ngn(txn.amount)}',
                      style: context.typography.amountHeroHighlight.copyWith(
                        color: amountColor,
                      ),
                    ),
                    if (txn.convertedAmount != null && txn.toCurrency == 'USDT') ...[
                      const SizedBox(height: 6),
                      Text(
                        '≈ ${CurrencyFormatter.usdt(txn.convertedAmount!)}',
                        style: context.typography.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 10),
                    StatusBadge(status: txn.status),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (txn.failureReason != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.destructiveMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.destructive, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(txn.failureReason!, style: context.typography.bodyMedium),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text('Details', style: context.typography.title),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Reference',
                      value: txn.reference ?? '—',
                      mono: true,
                    ),
                    _DetailRow(
                      label: 'Date',
                      value: DateFormatter.full(txn.date),
                    ),
                    _DetailRow(
                      label: 'Time',
                      value: DateFormatter.time(txn.date),
                    ),
                    if (txn.destination != null)
                      _DetailRow(label: 'To', value: txn.destination!),
                    if (txn.description != null)
                      _DetailRow(label: 'Narration', value: txn.description!),
                    if (txn.fromCurrency != null && txn.toCurrency != null)
                      _DetailRow(
                        label: 'Converted',
                        value: '${txn.fromCurrency} → ${txn.toCurrency}',
                      ),
                    if (txn.exchangeRate != null)
                      _DetailRow(
                        label: 'Rate',
                        value: txn.exchangeRate!.toStringAsFixed(2),
                      ),
                    if (txn.fee != null)
                      _DetailRow(
                        label: 'Fee',
                        value: CurrencyFormatter.ngn(txn.fee!),
                      ),
                    _DetailRow(
                      label: 'Status',
                      value: txn.status.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: context.typography.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.typography.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
