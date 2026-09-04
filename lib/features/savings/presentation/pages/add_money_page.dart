import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/savings_client.dart';

class AddMoneyPage extends ConsumerStatefulWidget {
  const AddMoneyPage({super.key});

  @override
  ConsumerState<AddMoneyPage> createState() => _AddMoneyPageState();
}

class _AddMoneyPageState extends ConsumerState<AddMoneyPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  String _currency = 'NGN';
  bool _isLoading = false;
  DepositInfo? _deposit;
  bool _depositError = false;

  @override
  void initState() {
    super.initState();
    _loadDeposit();
  }

  Future<void> _loadDeposit() async {
    try {
      final info = await ref.read(savingsClientProvider).getDepositInfo();
      if (mounted) {
        setState(() {
          _deposit = info;
          _depositError = false;
          _addressController.text = info.hasAddress ? info.address : '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _depositError = true);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _isCrypto => _currency != 'NGN';

  Future<void> _confirmDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));

    if (_isCrypto && ( _deposit == null || !_deposit!.hasAddress)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Link your wallet address to receive on-chain deposits first.')),
      );
      return;
    }

    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Confirm deposit?',
      details: [
        ConfirmationDetail(label: 'Amount', value: CurrencyFormatter.ngn(amount), isHighlighted: true),
        ConfirmationDetail(label: 'Currency', value: _currency),
        ConfirmationDetail(
          label: 'Destination',
          value: _isCrypto ? 'Vault contract' : 'Globmint Savings',
        ),
        ConfirmationDetail(label: 'Fee', value: '₦0.00'),
      ],
      confirmText: 'Confirm Deposit',
    );

    if (confirmed == true) {
      await _submitDeposit(amount);
    }
  }

  Future<void> _submitDeposit(double amount) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(transferServiceProvider).deposit(
            amount: amount,
            currency: _currency,
          );
      if (mounted) {
        ref.invalidate(accountSummaryProvider);
        ref.invalidate(transactionsProvider);
        setState(() => _isLoading = false);
        _showSuccess(amount);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deposit failed: $e')),
        );
      }
    }
  }

  Future<void> _linkAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your wallet address')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final info = await ref
          .read(savingsClientProvider)
          .setDepositAddress(address);
      if (mounted) {
        setState(() {
          _deposit = info;
          _isLoading = false;
        });
        ref.invalidate(depositInfoProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet linked successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not link wallet: $e')),
        );
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
    final summaryAsync = ref.watch(accountSummaryProvider);
    final availableBalance = summaryAsync.valueOrNull?.available.balance ?? 0;

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
                        CurrencyFormatter.ngn(availableBalance),
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
                  prefixText: _currency == 'NGN' ? '₦' : '',
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
                if (_isCrypto) ...[
                  Text('Crypto Deposit Address', style: context.typography.title),
                  const SizedBox(height: 12),
                  _depositInfoSection(context),
                  const SizedBox(height: 20),
                ],
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
                      const Icon(Icons.account_balance_wallet,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isCrypto ? 'Globmint Vault' : 'Globmint Savings',
                              style: context.typography.labelLarge,
                            ),
                            Text(
                              _isCrypto
                                  ? 'Sent to the vault contract on-chain'
                                  : 'Funds will be held securely',
                              style: context.typography.bodySmall,
                            ),
                          ],
                        ),
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
                    'Test network — no real money is moved',
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

  Widget _depositInfoSection(BuildContext context) {
    if (_deposit == null && _depositError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(
          'Deposit details are unavailable right now.',
          style: context.typography.bodyMedium,
        ),
      );
    }

    final deposit = _deposit;
    if (deposit == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              _infoRow(context, 'Network', deposit.network),
              _infoRow(context, 'Chain', '${deposit.chainId}'),
              _infoRow(context, 'Asset',
                  '${deposit.stablecoinSymbol} · ${deposit.stablecoinName}'),
              const Divider(height: 16, color: AppColors.border),
              if (deposit.vaultContract.isNotEmpty)
                _infoRow(context, 'Vault contract (send asset here)',
                    deposit.vaultContract, highlight: true)
              else
                _infoRow(
                  context,
                  'Deposit',
                  'USDC test token on Sepolia — link your wallet below to fund your savings.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Your wallet address', style: context.typography.bodyMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _addressController,
          enabled: !_isLoading,
          style: context.typography.bodyMedium,
          decoration: InputDecoration(
            hintText: '0x…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
        const SizedBox(height: 8),
        AppButton(
          text: deposit.hasAddress ? 'Update linked wallet' : 'Link wallet',
          onPressed: _linkAddress,
          variant: AppButtonVariant.secondary,
          isExpanded: true,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value,
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
