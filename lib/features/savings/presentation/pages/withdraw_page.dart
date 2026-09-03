import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/bank_account.dart';
import '../../../../shared/services/mock_transfer_service.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final MockTransferService _service = MockTransferService();
  BankAccount? _selectedAccount;
  bool _loadingAccounts = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _service.getSavedAccounts();
    if (mounted) {
      setState(() {
        _selectedAccount = accounts.firstWhere((a) => a.isDefault,
            orElse: () => accounts.first);
        _loadingAccounts = false;
      });
    }
  }

  void _openAccountSheet() {
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select bank account', style: context.typography.headline),
              ),
            ),
            const SizedBox(height: 12),
            // Fetch accounts
            FutureBuilder<List<BankAccount>>(
              future: _service.getSavedAccounts(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? <BankAccount>[];
                return Column(
                  children: accounts.map((acc) {
                    final isSelected = _selectedAccount?.id == acc.id;
                    return ListTile(
                      onTap: () {
                        setState(() => _selectedAccount = acc);
                        Navigator.pop(context);
                      },
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryMuted : AppColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
                      ),
                      title: Text(acc.bankName, style: context.typography.labelLarge),
                      subtitle: Text(acc.maskedNumber, style: context.typography.bodySmall),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : const Icon(Icons.circle_outlined, color: AppColors.textTertiary),
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
    if (!_formKey.currentState!.validate() || _selectedAccount == null) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));

    final account = _selectedAccount!;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _loading = false);
      context.push('/savings/withdraw-review', extra: {
        'amount': amount,
        'account': account,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Withdraw')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount to withdraw', style: context.typography.title),
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
                const SizedBox(height: 20),
                Text('Destination bank account', style: context.typography.title),
                const SizedBox(height: 12),
                if (_loadingAccounts)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else
                  GestureDetector(
                    onTap: _openAccountSheet,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.account_balance, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedAccount?.bankName ?? 'Select bank', style: context.typography.labelLarge),
                                Text(_selectedAccount?.maskedNumber ?? 'Tap to select', style: context.typography.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
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
