import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/beneficiary.dart';

class BeneficiaryDetailsPage extends ConsumerStatefulWidget {
  const BeneficiaryDetailsPage({super.key, this.beneficiary});

  final Beneficiary? beneficiary;

  @override
  ConsumerState<BeneficiaryDetailsPage> createState() => _BeneficiaryDetailsPageState();
}

class _BeneficiaryDetailsPageState extends ConsumerState<BeneficiaryDetailsPage> {
  late Beneficiary _beneficiary;

  @override
  void initState() {
    super.initState();
    _beneficiary = widget.beneficiary ??
        Beneficiary(
          id: 'ben_000',
          name: 'Unknown',
          address: '0x0000000000000000000000000000000000000000',
        );
  }

  Future<void> _editBeneficiary() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _beneficiary.name);
    final addressController = TextEditingController(text: _beneficiary.address);
    final isFavoriteController = ValueNotifier(_beneficiary.isFavorite);

    final result = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text('Edit Beneficiary', style: context.typography.headline),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Name',
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: addressController,
                    label: 'Crypto Address',
                    hint: 'Paste their address here',
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isFavoriteController.value,
                        onChanged: (v) =>
                            setState(() => isFavoriteController.value = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                      Text('Mark as favorite', style: context.typography.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            AppButton(
              text: 'Save',
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await ref.read(beneficiaryServiceProvider).update(
            id: _beneficiary.id,
            name: nameController.text.trim(),
            address: addressController.text.trim(),
            isFavorite: isFavoriteController.value,
          );
      ref.invalidate(beneficiariesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Beneficiary updated')),
        );
      }
    }
  }

  Future<void> _removeBeneficiary() async {
    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Remove ${_beneficiary.name}?',
      details: [
        ConfirmationDetail(label: 'Address', value: _beneficiary.shortAddress),
      ],
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      await ref.read(beneficiaryServiceProvider).remove(_beneficiary.id);
      ref.invalidate(beneficiariesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_beneficiary.name} removed')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Beneficiary')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _beneficiary.isFavorite
                            ? AppColors.warningMuted
                            : AppColors.primaryMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _beneficiary.isFavorite ? Icons.star : Icons.person,
                        color: _beneficiary.isFavorite ? AppColors.warning : AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _beneficiary.name,
                      style: context.typography.headline,
                      textAlign: TextAlign.center,
                    ),
                    if (_beneficiary.isFavorite) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'FAVORITE',
                          style: context.typography.labelSmall.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child:
                                Text('Crypto address', style: context.typography.labelMedium),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _beneficiary.address,
                            style: context.typography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Send to this address',
                icon: Icons.send_outlined,
                isExpanded: true,
                onPressed: () {
                  context.push('/savings/withdraw', extra: {'address': _beneficiary.address});
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Edit Beneficiary',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                onPressed: _editBeneficiary,
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: _removeBeneficiary,
                  icon: const Icon(Icons.delete_outline, color: AppColors.destructive, size: 20),
                  label: Text(
                    'Remove Beneficiary',
                    style: context.typography.labelLarge.copyWith(color: AppColors.destructive),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}