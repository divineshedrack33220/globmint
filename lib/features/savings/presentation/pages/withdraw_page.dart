import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/widgets/stablecoin_risk_disclosure.dart';

class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key, this.initialAddress});

  final String? initialAddress;

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawNetwork {
  const _WithdrawNetwork({
    required this.name,
    required this.code,
    required this.available,
  });

  final String name;
  final String code;
  final bool available;
}

const _networks = <_WithdrawNetwork>[
  _WithdrawNetwork(name: 'Ethereum (Sepolia)', code: 'ERC-20', available: true),
  _WithdrawNetwork(name: 'BSC (BEP-20)', code: 'BEP-20', available: false),
  _WithdrawNetwork(name: 'Tron (TRC-20)', code: 'TRC-20', available: false),
];

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  bool _loading = false;
  _WithdrawNetwork _network = _networks.first;

  double? _usdcEstimate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress?.trim() ?? '';
    if (initial.isNotEmpty) _addressController.text = initial;
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
    if (!_network.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This network is coming soon. Use Ethereum (Sepolia) for now.')),
      );
      return;
    }
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
        'network': _network.name,
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
                Text('Withdrawal network', style: context.typography.title),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in _networks)
                      _NetworkOption(
                        network: n,
                        isSelected: _network.code == n.code,
                        onTap: n.available
                            ? () => setState(() => _network = n)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Destination crypto address', style: context.typography.title),
                const SizedBox(height: 6),
                Text(
                  _network.available
                      ? 'USDC will be sent here on-chain from your vault.'
                      : 'This network is not available yet.',
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  style: context.typography.bodyMedium,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Enter a destination address';
                    if (value.contains(RegExp(r'\s'))) return 'Address must not contain spaces';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Paste any crypto address…',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 24),
                const StablecoinRiskDisclosure(),
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

class _NetworkOption extends StatelessWidget {
  const _NetworkOption({
    required this.network,
    required this.isSelected,
    this.onTap,
  });

  final _WithdrawNetwork network;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              network.name,
              style: context.typography.labelMedium.copyWith(
                color: enabled ? color : AppColors.textDisabled,
              ),
            ),
            if (!enabled) ...[
              const SizedBox(width: 8),
              Text(
                'Coming soon',
                style: context.typography.labelSmall.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
