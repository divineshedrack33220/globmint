import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../shared/models/beneficiary.dart';

class SendToBeneficiaryPage extends ConsumerStatefulWidget {
  const SendToBeneficiaryPage({super.key, this.beneficiary});

  final Beneficiary? beneficiary;

  @override
  ConsumerState<SendToBeneficiaryPage> createState() => _SendToBeneficiaryPageState();
}

class _SendToBeneficiaryPageState extends ConsumerState<SendToBeneficiaryPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  Beneficiary? _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.beneficiary;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose beneficiary', style: context.typography.headline),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Beneficiary>>(
              future: ref.watch(beneficiaryServiceProvider).getBeneficiaries(),
              builder: (context, snapshot) {
                final benes = snapshot.data ?? <Beneficiary>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: SkeletonActionRow(count: 3),
                  );
                }
                return Column(
                  children: benes.map((b) {
                    final isSelected = _selected?.id == b.id;
                    return AnimatedPress(
                      onTap: () {
                        setState(() => _selected = b);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryMuted.withValues(alpha: 0.3) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: b.isFavorite ? AppColors.warningMuted : AppColors.primaryMuted,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  b.isFavorite ? Icons.star : Icons.person,
                                  color: b.isFavorite ? AppColors.warning : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name, style: context.typography.labelLarge),
                                    const SizedBox(height: 2),
                                    Text(
                                      b.shortAddress,
                                      style: context.typography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      ),
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
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a beneficiary first')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _loading = false);
      context.push('/savings/withdraw-review', extra: {
        'amount': amount,
        'destination': _selected!.address,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Send to Beneficiary')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recipient', style: context.typography.title),
                const SizedBox(height: 12),
                AnimatedPress(
                  onTap: _openBeneficiarySheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _selected != null
                                ? AppColors.primaryMuted
                                : AppColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person,
                            color: _selected != null ? AppColors.primary : AppColors.textTertiary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _selected == null
                              ? Text('Choose a beneficiary', style: context.typography.bodyMedium)
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_selected!.name, style: context.typography.labelLarge),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selected!.shortAddress,
                                      style: context.typography.bodySmall,
                                    ),
                                  ],
                                ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Amount (NGN)', style: context.typography.title),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: context.typography.amountLarge,
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    hintText: '0.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter an amount';
                    final parsed = double.tryParse(v.replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height:16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'USDC will be sent from your vault to the saved address.',
                          style: context.typography.labelMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
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