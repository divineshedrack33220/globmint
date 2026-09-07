import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';

class TransferReviewPage extends ConsumerStatefulWidget {
  const TransferReviewPage({
    super.key,
    this.amount,
    this.accountName,
    this.accountNumber,
    this.bankName,
    this.note,
  });

  final double? amount;
  final String? accountName;
  final String? accountNumber;
  final String? bankName;
  final String? note;

  @override
  ConsumerState<TransferReviewPage> createState() => _TransferReviewPageState();
}

class _TransferReviewPageState extends ConsumerState<TransferReviewPage> {
  bool _isLoading = false;

  Future<void> _confirmTransfer({
    required double amount,
    required double fee,
  }) async {
    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Confirm transfer?',
      description: 'This will send money to your beneficiary.',
      details: [
        ConfirmationDetail(label: 'Amount', value: CurrencyFormatter.ngn(amount), isHighlighted: true),
        ConfirmationDetail(label: 'Transfer fee', value: CurrencyFormatter.ngn(fee)),
        ConfirmationDetail(
          label: 'To',
          value: '${widget.accountName ?? 'Beneficiary'} • ${widget.bankName ?? ''}',
        ),
        ConfirmationDetail(label: 'Total', value: CurrencyFormatter.ngn(amount + fee)),
      ],
      confirmText: 'Confirm Transfer',
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ref.read(transferServiceProvider).transfer(
          amount: amount,
          currency: 'NGN',
          accountName: widget.accountName,
          accountNumber: widget.accountNumber,
          bankName: widget.bankName,
          narration: widget.note,
        );
        ref.invalidate(accountSummaryProvider);
        ref.invalidate(transactionsProvider);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      if (mounted) {
        context.push('/pay/result', extra: {
          'amount': amount,
          'accountName': widget.accountName,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.amount ?? 0;
    final fee = 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Transfer')),
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
                  children: [
                    Text('You are sending', style: context.typography.labelMedium),
                    const SizedBox(height: 6),
                    Text(CurrencyFormatter.ngn(a), style: context.typography.amountHero),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.accountName ?? 'Beneficiary', style: context.typography.labelLarge),
                              Text(
                                '${widget.bankName ?? ''} • •••• ${widget.accountNumber != null && widget.accountNumber!.length >= 4 ? widget.accountNumber!.substring(widget.accountNumber!.length - 4) : ''}',
                                style: context.typography.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ReviewRow(label: 'Amount', value: CurrencyFormatter.ngn(a)),
              _ReviewRow(label: 'Transfer fee', value: CurrencyFormatter.ngn(fee)),
              _ReviewRow(
                label: 'Total',
                value: CurrencyFormatter.ngn(a + fee),
                highlight: true,
              ),
              if (widget.note != null && widget.note!.isNotEmpty) ...[
                const Divider(color: AppColors.divider, height: 24),
                _ReviewRow(label: 'Note', value: widget.note!),
              ],
              const Divider(color: AppColors.divider, height: 24),
              const SizedBox(height: 32),
              AppButton(
                text: 'Send Transfer',
                isExpanded: true,
                isLoading: _isLoading,
                onPressed: () => _confirmTransfer(amount: a, fee: fee),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.typography.bodyMedium),
          Text(
            value,
            style: (highlight ? context.typography.amountMedium : context.typography.labelLarge)
                .copyWith(color: highlight ? AppColors.primary : null),
          ),
        ],
      ),
    );
  }
}
