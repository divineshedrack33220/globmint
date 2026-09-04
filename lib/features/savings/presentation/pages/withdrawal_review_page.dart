import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../shared/models/bank_account.dart';

class WithdrawalReviewPage extends ConsumerStatefulWidget {
  const WithdrawalReviewPage({super.key, this.amount, this.account});

  final double? amount;
  final BankAccount? account;

  @override
  ConsumerState<WithdrawalReviewPage> createState() => _WithdrawalReviewPageState();
}

class _WithdrawalReviewPageState extends ConsumerState<WithdrawalReviewPage> {
  bool _isProcessing = false;

  Future<void> _confirmWithdrawal() async {
    final a = widget.amount ?? 0;
    final acc = widget.account;
    if (a <= 0 || acc == null) return;

    final fee = a * 0.01;

    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Finalize withdrawal?',
      details: [
        ConfirmationDetail(label: 'Amount', value: CurrencyFormatter.ngn(a), isHighlighted: true),
        ConfirmationDetail(label: 'Fee', value: CurrencyFormatter.ngn(fee)),
        ConfirmationDetail(label: 'To', value: acc.maskedNumber),
        ConfirmationDetail(label: 'Receive', value: CurrencyFormatter.ngn(a - fee)),
      ],
      confirmText: 'Confirm',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(transferServiceProvider).withdraw(
              amount: a,
              currency: 'NGN',
              bankId: acc.id,
            );
        if (mounted) {
          ref.invalidate(accountSummaryProvider);
          ref.invalidate(transactionsProvider);
          setState(() => _isProcessing = false);
          SuccessDialog.show(
            context: context,
            type: SuccessDialogType.success,
            title: 'Withdrawal Initiated',
            amount: CurrencyFormatter.ngn(a - fee),
            subtitle: 'Funds will arrive within 5 minutes',
            onPressed: () => context.go('/savings'),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Withdrawal failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.amount ?? 0;
    final acc = widget.account;
    final fee = a * 0.01;

    final availableAfter = ref.watch(accountSummaryProvider).whenOrNull(
          data: (s) => s.available.balance - a,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Withdrawal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount summary
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
                    Text('You pay (withdrawal)', style: context.typography.labelMedium),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.ngn(a), style: context.typography.amountHero),
                    const SizedBox(height: 4),
                    if (acc != null) Text(acc.maskedNumber, style: context.typography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ReviewRow(
                label: 'Fee (1%)',
                value: CurrencyFormatter.ngn(fee),
              ),
              _ReviewRow(
                label: 'You receive',
                value: CurrencyFormatter.ngn(a - fee),
                highlight: true,
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 8),
              _ReviewRow(
                label: 'Available after',
                value: availableAfter != null
                    ? CurrencyFormatter.ngn(availableAfter)
                    : '—',
              ),
              const SizedBox(height: 8),
              _ReviewRow(
                label: 'Processing time',
                value: 'Up to 5 min',
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Confirm Withdrawal',
                isExpanded: true,
                isLoading: _isProcessing,
                onPressed: _confirmWithdrawal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

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
            style: (highlight
                    ? context.typography.amountMedium
                    : context.typography.labelLarge)
                .copyWith(color: highlight ? AppColors.primary : null),
          ),
        ],
      ),
    );
  }
}
