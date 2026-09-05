import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Legacy NGN bank-transfer form. The funds for this flow live on the cleared
/// NGN ledger; kept only for the manual-account route.
class BankTransferPage extends ConsumerStatefulWidget {
  const BankTransferPage({super.key});

  @override
  ConsumerState<BankTransferPage> createState() => _BankTransferPageState();
}

class _BankTransferPageState extends ConsumerState<BankTransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankController = TextEditingController();
  final _noteController = TextEditingController();

  bool _loading = false;

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _loading = false);
      context.push('/pay/review', extra: {
        'amount': amount,
        'accountName': 'Beneficiary',
        'accountNumber': _accountNumberController.text,
        'bankName': _bankController.text,
        'note': _noteController.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bank Transfer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount', style: context.typography.title),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _amountController,
                  label: 'Amount (NGN)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter an amount';
                    final parsed = double.tryParse(v.replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _accountNumberController,
                  label: 'Account Number',
                  hint: '10 digits',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _bankController,
                  label: 'Bank',
                  hint: 'e.g. GTBank',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _noteController,
                  label: 'Note (optional)',
                  hint: 'What\u2019s this for?',
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Continue',
                  onPressed: _continue,
                  isExpanded: true,
                  isLoading: _loading,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}