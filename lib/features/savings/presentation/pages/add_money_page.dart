import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/mock_data.dart';

class AddMoneyPage extends StatefulWidget {
  const AddMoneyPage({super.key});

  @override
  State<AddMoneyPage> createState() => _AddMoneyPageState();
}

class _AddMoneyPageState extends State<AddMoneyPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _currency = 'NGN';
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));

    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Confirm deposit?',
      details: [
        ConfirmationDetail(label: 'Amount', value: CurrencyFormatter.ngn(amount), isHighlighted: true),
        ConfirmationDetail(label: 'Currency', value: _currency),
        ConfirmationDetail(label: 'Destination', value: 'Globmint Savings'),
        ConfirmationDetail(label: 'Fee', value: '₦0.00'),
      ],
      confirmText: 'Confirm Deposit',
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccess(amount);
      }
    }
  }

  void _showSuccess(double amount) {
    SuccessDialog.show(
      context: context,
      type: SuccessDialogType.success,
      title: 'Deposit Successful',
      amount: CurrencyFormatter.ngn(amount),
      subtitle: 'Added to your available balance',
      onPressed: () => context.go('/home'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = MockData.availableAccount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add Money')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available balance
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Balance',
                        style: context.typography.bodyMedium,
                      ),
                      Text(
                        CurrencyFormatter.ngn(available.balance),
                        style: context.typography.amountMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Amount', style: context.typography.title),
                const SizedBox(height: 12),
                AmountTextField(
                  controller: _amountController,
                  label: null,
                  hint: '0.00',
                  prefixText: _currency == 'NGN' ? '₦' : 'USDT ',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter an amount';
                    final parsed = double.tryParse(v.replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                    if (_currency == 'NGN' && parsed < 1000) return 'Minimum is ₦1,000';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text('Currency', style: context.typography.title),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _CurrencyChip(
                      label: 'NGN',
                      isSelected: _currency == 'NGN',
                      onTap: () => setState(() => _currency = 'NGN'),
                    ),
                    const SizedBox(width: 12),
                    _CurrencyChip(
                      label: 'USDT',
                      isSelected: _currency == 'USDT',
                      onTap: () => setState(() => _currency = 'USDT'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Destination', style: context.typography.title),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Globmint Savings', style: context.typography.labelLarge),
                          Text('Funds will be held securely', style: context.typography.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Continue',
                  onPressed: _confirmDeposit,
                  isExpanded: true,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'This is a prototype — no real money is moved',
                    style: context.typography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryMuted : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: context.typography.labelLarge.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
