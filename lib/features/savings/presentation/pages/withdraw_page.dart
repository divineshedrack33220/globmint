import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key});

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  bool _loading = false;

  double? _usdcEstimate;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateQuote);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateQuote);
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _updateQuote() {
    final parsed = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (parsed == null || parsed <= 0) {
      if (_usdcEstimate != null && mounted) setState(() => _usdcEstimate = null);
      return;
    }
    ref
        .read(conversionServiceProvider)
        .getQuote(amount: parsed, fromCurrency: 'NGN', toCurrency: 'USDC')
        .then((q) {
      if (mounted && _amountController.text.isNotEmpty) {
        setState(() => _usdcEstimate = q.outputAmount);
      }
    }).catchError((_) {
      if (mounted) setState(() => _usdcEstimate = null);
    });
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination crypto address')),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _loading = false);
      context.push('/savings/withdraw-review', extra: {
        'amount': amount,
        'destination': address,
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
                if (_usdcEstimate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '≈ ${_usdcEstimate!.toStringAsFixed(2)} USDC sent on-chain',
                    style: context.typography.bodySmall.copyWith(
                        color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Destination crypto address', style: context.typography.title),
                const SizedBox(height: 6),
                Text(
                  'USDC will be sent here on-chain from your vault.',
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  style: context.typography.bodyMedium,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Enter a destination address';
                    if (!_looksLikeAddress(value)) return 'Enter a valid address (0x…)';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '0x…',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
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

  bool _looksLikeAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.length != 42) return false;
    if (!trimmed.startsWith('0x') && !trimmed.startsWith('0X')) return false;
    final hex = trimmed.substring(2);
    return RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(hex);
  }
}
