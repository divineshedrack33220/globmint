import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../shared/models/exchange_rate.dart';

class ConversionPage extends ConsumerStatefulWidget {
  const ConversionPage({super.key});

  @override
  ConsumerState<ConversionPage> createState() => _ConversionPageState();
}

class _ConversionPageState extends ConsumerState<ConversionPage> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  ConversionQuote? _quote;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _calculateQuote(String value) async {
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null || parsed <= 0) {
      setState(() => _quote = null);
      return;
    }
    try {
      final q = await ref
          .read(conversionServiceProvider)
          .getQuote(amount: parsed, fromCurrency: 'NGN', toCurrency: 'USDT');
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) {
        setState(() => _quote = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch rate: $e')),
        );
      }
    }
  }

  Future<void> _confirmConversion() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0 || _quote == null) return;

    final q = _quote!;
    final net = q.outputAmount;

    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Confirm conversion?',
      details: [
        ConfirmationDetail(label: 'Converting', value: CurrencyFormatter.ngn(amount)),
        ConfirmationDetail(label: 'Exchange Rate', value: '1 USDT = ₦${q.rate.toStringAsFixed(2)}'),
        ConfirmationDetail(label: 'Fee', value: CurrencyFormatter.ngn(q.feeAmount)),
        ConfirmationDetail(label: 'You receive', value: CurrencyFormatter.usdt(net), isHighlighted: true),
        ConfirmationDetail(label: 'Rate expires', value: DateFormatter.time(q.expiresAt)),
      ],
      confirmText: 'Confirm Conversion',
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(conversionServiceProvider).convert(
              amount: amount,
              fromCurrency: 'NGN',
              toCurrency: 'USDT',
            );
        if (mounted) {
          ref.invalidate(accountSummaryProvider);
          ref.invalidate(transactionsProvider);
          setState(() => _isLoading = false);
          _showSuccess(net);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Conversion failed: $e')),
          );
        }
      }
    }
  }

  void _showSuccess(double amount) {
    SuccessDialog.show(
      context: context,
      type: SuccessDialogType.conversion,
      title: 'Conversion Complete',
      amount: CurrencyFormatter.usdt(amount),
      subtitle: 'Added to your savings',
      onPressed: () => context.go('/savings'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Convert to USDT')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // You're converting
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    Text('You are converting', style: context.typography.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      _amountController.text.isEmpty
                          ? '₦0.00'
                          : '₦${_amountController.text.replaceAll(RegExp(r'[^\d,.]'), '')}',
                      style: context.typography.amountLarge,
                    ),
                    const SizedBox(height: 8),
                    const Icon(Icons.arrow_downward, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text('to', style: context.typography.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      q == null
                          ? '0.00 USDT'
                          : CurrencyFormatter.usdt(q.outputAmount),
                      style: context.typography.amountLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AmountTextField(
                controller: _amountController,
                hint: 'Enter amount in NGN',
                prefixText: '₦',
                onChanged: _calculateQuote,
              ),
              const SizedBox(height: 20),
              // Rate info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    _RateRow(
                      label: 'Exchange Rate',
                      value: q == null
                          ? '—'
                          : '1 USDT = ₦${q.rate.toStringAsFixed(2)}',
                    ),
                    const Divider(color: AppColors.divider, height: 20),
                    _RateRow(
                      label: 'Fee',
                      value: q == null
                          ? '—'
                          : CurrencyFormatter.ngn(q.feeAmount),
                    ),
                    const Divider(color: AppColors.divider, height: 20),
                    _RateRow(
                      label: 'Rate expires',
                      value: q == null
                          ? '—'
                          : DateFormatter.time(q.expiresAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Continue',
                onPressed: _confirmConversion,
                isExpanded: true,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.typography.bodyMedium),
        Text(value, style: context.typography.labelMedium),
      ],
    );
  }
}
