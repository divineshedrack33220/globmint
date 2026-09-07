import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/models.dart';
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
  String? _savedAddress;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress?.trim() ?? '';
    if (initial.isNotEmpty) _addressController.text = initial;
    _amountController.addListener(_updateQuote);
    _addressController.addListener(_onAddressChanged);
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateQuote);
    _addressController.removeListener(_onAddressChanged);
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddress() async {
    final depositInfo = ref.read(depositInfoProvider).valueOrNull;
    if (depositInfo != null) {
      final saved = depositInfo.address;
      setState(() => _savedAddress = saved.isNotEmpty ? saved : null);
    }
  }

  void _onAddressChanged() {
    if (mounted) setState(() {});
  }

  /// True when the destination is the vault's own address or the contract:
  /// funds would loop back into the vault while still costing the user. The
  /// server rejects this too; this check warns before submission.
  bool _isSelfSend(String address) {
    final lower = address.trim().toLowerCase();
    if (lower.isEmpty) return false;
    final info = ref.read(depositInfoProvider).valueOrNull;
    final vaultAddr = (info?.address ?? '').toLowerCase();
    final vaultContract = (info?.vaultContract ?? '').toLowerCase();
    if (lower == vaultAddr) return true;
    if (vaultContract.isNotEmpty && lower == vaultContract) return true;
    return false;
  }

  /// Suggestable saved destinations: the user's own saved addresses that
  /// carry a name. An address without a name is deliberately excluded.
  List<Beneficiary> _suggestions(List<Beneficiary> beneficiaries) {
    final typed = _addressController.text.trim().toLowerCase();
    return beneficiaries
        .where((b) => b.name.trim().isNotEmpty)
        .where((b) =>
            typed.isEmpty ||
            b.name.toLowerCase().contains(typed) ||
            b.address.toLowerCase().contains(typed))
        .toList();
  }

  void _pickAddress(Beneficiary b) {
    setState(() {
      _addressController.text = b.address;
      _savedAddress = b.address;
    });
  }

  void _clearSaved() {
    setState(() {
      _savedAddress = null;
      _addressController.clear();
    });
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
    final address = _savedAddress ?? _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination crypto address')),
      );
      return;
    }
    if (_isSelfSend(address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'That is your vault\u2019s own address — funds would go in a circle. Use an external wallet address.')),
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
    final depositInfo = ref.watch(depositInfoProvider).valueOrNull;
    final beneficiariesAsync = ref.watch(beneficiariesProvider);
    final beneficiaries =
        beneficiariesAsync.valueOrNull ?? const <Beneficiary>[];
    final suggestions = _suggestions(beneficiaries);
    final suggestionsActive = suggestions.isNotEmpty;
    final vaultAddress = (depositInfo?.address ?? '').toLowerCase();
    final vaultContract = (depositInfo?.vaultContract ?? '').toLowerCase();
    final entered = _addressController.text.trim().toLowerCase();
    final isSelfSend = entered.isNotEmpty &&
        (entered == vaultAddress || (vaultContract.isNotEmpty && entered == vaultContract));

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
                if (suggestionsActive) ...[
                  Text('Saved addresses', style: context.typography.labelLarge),
                  const SizedBox(height: 8),
                  ...suggestions.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SavedAddressChip(
                        name: b.name,
                        address: b.address,
                        isSelected: _savedAddress == b.address,
                        onTap: () => _pickAddress(b),
                        onRemoved: _clearSaved,
                      ),
                    ),
                  ),
                  if (_savedAddress == null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Suggestions come from your saved addresses.',
                      style: context.typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
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
                    hintText: _savedAddress != null
                        ? 'Paste or edit another address…'
                        : 'Paste any crypto address…',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
                    suffixIcon: _savedAddress != null
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove saved address',
                            onPressed: _clearSaved,
                          )
                        : null,
                  ),
                ),
                if (isSelfSend) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'That is your vault\u2019s own address — funds would go in a circle and you would still be charged. Use an external wallet address.',
                          style: context.typography.bodySmall.copyWith(
                              color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ],
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

class _SavedAddressChip extends StatelessWidget {
  const _SavedAddressChip({
    required this.name,
    required this.address,
    required this.isSelected,
    required this.onTap,
    required this.onRemoved,
  });

  final String name;
  final String address;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemoved;

  String get _label {
    if (address.length <= 22) return address;
    return '${address.substring(0, 10)}…${address.substring(address.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySubtle : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySubtle
                    : AppColors.primaryOverlay,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.bookmark_outline,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.typography.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _label,
                    style: context.typography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
              tooltip: 'Clear',
              onPressed: onRemoved,
            ),
          ],
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
          color: isSelected ? AppColors.primarySubtle : AppColors.surface,
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
