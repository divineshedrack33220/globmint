import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/services/mock_transfer_service.dart';
import '../../../../shared/models/beneficiary.dart';

class BankTransferPage extends StatefulWidget {
  const BankTransferPage({super.key});

  @override
  State<BankTransferPage> createState() => _BankTransferPageState();
}

class _BankTransferPageState extends State<BankTransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankController = TextEditingController();
  final _noteController = TextEditingController();
  final MockTransferService _service = MockTransferService();

  String? _resolvedName;
  bool _resolving = false;
  bool _loading = false;

  void _resolveAccount() async {
    final num = _accountNumberController.text.replaceAll(' ', '');
    if (num.length != 10) {
      setState(() => _resolvedName = null);
      return;
    }
    setState(() => _resolving = true);
    final name = await _service.resolveAccount(num);
    if (mounted) {
      setState(() {
        _resolvedName = name;
        _resolving = false;
      });
    }
  }

  void _openBeneficiarySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('Choose recipient', style: context.typography.headline)),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Beneficiary>>(
              future: _service.getBeneficiaries(),
              builder: (context, snapshot) {
                final benes = snapshot.data ?? <Beneficiary>[];
                return Column(
                  children: benes.map((b) {
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _accountNumberController.text = b.accountNumber;
                          _bankController.text = b.bank;
                          _noteController.text = 'Transfer to ${b.name}';
                          _resolvedName = b.name;
                        });
                        Navigator.pop(context);
                      },
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                      ),
                      title: Text(b.name, style: context.typography.labelLarge),
                      subtitle: Text('${b.bank} • ${b.maskedNumber}', style: context.typography.bodySmall),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _loading = false);
      context.push('/pay/review', extra: {
        'amount': amount,
        'accountName': _resolvedName ?? 'Beneficiary',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amount', style: context.typography.title),
                    GestureDetector(
                      onTap: _openBeneficiarySheet,
                      child: Row(
                        children: [
                          Text('Recipients', style: context.typography.labelMedium.copyWith(color: AppColors.primary)),
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AmountTextField(
                  controller: _amountController,
                  prefixText: '₦',
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
                  onChanged: (_) => _resolveAccount(),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _bankController,
                  label: 'Bank',
                  hint: 'e.g. GTBank',
                ),
                if (_resolving) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                ] else if (_resolvedName != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.successMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_resolvedName!, style: context.typography.labelLarge.copyWith(color: AppColors.success)),
                        ),
                      ],
                    ),
                  ),
                ],
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
                Center(
                  child: Text(
                    'Prototype — no real money moves',
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
