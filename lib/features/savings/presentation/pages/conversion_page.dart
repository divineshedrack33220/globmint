import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../shared/services/mock_data.dart';

class ConversionPage extends StatefulWidget {
  const ConversionPage({super.key});

  @override
  State<ConversionPage> createState() => _ConversionPageState();
}

class _ConversionPageState extends State<ConversionPage> {
  final _amountController = TextEditingController();
  final _rate = MockData.exchangeRate;
  bool _isLoading = false;
  double? _quoteAmount;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculateQuote(String value) {
    final parsed = double.tryParse(value.replaceAll(',', ''));
    setState(() {
      _quoteAmount = parsed == null || parsed <= 0
          ? null
          : (parsed - (parsed * _rate.fee / 100)) / _rate.rate;
    });
  }

  Future<void> _confirmConversion() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    final feeAmount = amount * _rate.fee / 100;
    final net = _quoteAmount ?? 0;

    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Confirm conversion?',
      details: [
        ConfirmationDetail(label: 'Converting', value: CurrencyFormatter.ngn(amount)),
        ConfirmationDetail(label: 'Exchange Rate', value: '1 USDT = ₦${_rate.rate.toStringAsFixed(2)}'),
        ConfirmationDetail(label: 'Fee (${_rate.fee}%)', value: CurrencyFormatter.ngn(feeAmount)),
        ConfirmationDetail(label: 'You receive', value: CurrencyFormatter.usdt(net), isHighlighted: true),
        ConfirmationDetail(label: 'Rate expires', value: DateFormatter.time(_rate.expiresAt)),
      ],
      confirmText: 'Confirm Conversion',
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccess(net);
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
                      _quoteAmount == null
                          ? '0.00 USDT'
                          : CurrencyFormatter.usdt(_quoteAmount!),
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
                      value: '1 USDT = ₦${_rate.rate.toStringAsFixed(2)}',
                    ),
                    const Divider(color: AppColors.divider, height: 20),
                    _RateRow(
                      label: 'Fee (${_rate.fee}%)',
                      value: CurrencyFormatter.ngn(
                        _amountController.text.isEmpty
                            ? 0
                            : (double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0) * _rate.fee / 100,
                      ),
                    ),
                    const Divider(color: AppColors.divider, height: 20),
                    _RateRow(
                      label: 'Rate expires',
                      value: DateFormatter.time(_rate.expiresAt),
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
