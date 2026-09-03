import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/beneficiary.dart';
import '../../../../shared/services/mock_data.dart';

class BeneficiaryDetailsPage extends StatefulWidget {
  const BeneficiaryDetailsPage({super.key, this.beneficiary});

  final Beneficiary? beneficiary;

  @override
  State<BeneficiaryDetailsPage> createState() => _BeneficiaryDetailsPageState();
}

class _BeneficiaryDetailsPageState extends State<BeneficiaryDetailsPage> {
  late Beneficiary _beneficiary;

  @override
  void initState() {
    super.initState();
    _beneficiary = widget.beneficiary ??
        Beneficiary(
          id: 'ben_000',
          name: 'Unknown',
          bank: '—',
          accountNumber: '0000000000',
        );
  }

  Future<void> _editBeneficiary() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _beneficiary.name);
    final bankController = TextEditingController(text: _beneficiary.bank);
    final accountNumberController =
        TextEditingController(text: _beneficiary.accountNumber);
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
                    label: 'Full Name',
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: bankController,
                    label: 'Bank Name',
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: accountNumberController,
                    label: 'Account Number (10 digits)',
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.length != 10 ? '10 digits' : null,
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
                  setState(() {
                    _beneficiary = _beneficiary.copyWith(
                      name: nameController.text.trim(),
                      bank: bankController.text.trim(),
                      accountNumber: accountNumberController.text.trim(),
                      isFavorite: isFavoriteController.value,
                    );
                  });
                  MockData.updateBeneficiary(_beneficiary);
                  Navigator.pop(context, true);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
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
        ConfirmationDetail(label: 'Bank', value: _beneficiary.bank),
        ConfirmationDetail(label: 'Account', value: _beneficiary.maskedNumber),
      ],
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      MockData.removeBeneficiary(_beneficiary.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_beneficiary.name} removed')),
      );
      context.pop();
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
                    const SizedBox(height: 4),
                    Text(_beneficiary.bank, style: context.typography.bodyMedium),
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
                          _DetailRow(
                            label: 'Account Number',
                            value: _beneficiary.accountNumber,
                          ),
                          const Divider(color: AppColors.divider, height: 20),
                          _DetailRow(
                            label: 'Bank',
                            value: _beneficiary.bank,
                          ),
                          const Divider(color: AppColors.divider, height: 20),
                          _DetailRow(
                            label: 'Account Name',
                            value: _beneficiary.name,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Send Money',
                icon: Icons.send_outlined,
                isExpanded: true,
                onPressed: () {
                  context.push('/pay/send-beneficiary');
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.typography.bodyMedium),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: context.typography.labelLarge,
          ),
        ),
      ],
    );
  }
}
