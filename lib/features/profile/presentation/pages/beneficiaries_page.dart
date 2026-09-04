import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../shared/models/beneficiary.dart';

class BeneficiariesPage extends ConsumerStatefulWidget {
  const BeneficiariesPage({super.key});

  @override
  ConsumerState<BeneficiariesPage> createState() => _BeneficiariesPageState();
}

class _BeneficiariesPageState extends ConsumerState<BeneficiariesPage> {
  Future<void> _addBeneficiary() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final bankController = TextEditingController();
    final accountNumberController = TextEditingController();
    final isFavoriteController = ValueNotifier(false);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text('Add Beneficiary', style: context.typography.headline),
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
                        onChanged: (v) => setState(() => isFavoriteController.value = v ?? false),
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
              text: 'Add',
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'bank': bankController.text.trim(),
                    'accountNumber': accountNumberController.text.trim(),
                    'isFavorite': isFavoriteController.value,
                  });
                }
              },
            ),
          ],
        ),
      ),
    );

    if (result is Map<String, dynamic>) {
      await ref.read(beneficiaryServiceProvider).create(
            name: result['name'] as String,
            bank: result['bank'] as String,
            accountNumber: result['accountNumber'] as String,
            isFavorite: result['isFavorite'] as bool,
          );
      ref.invalidate(beneficiariesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Beneficiary added')),
        );
      }
    }
  }

  Future<void> _removeBeneficiary(Beneficiary beneficiary) async {
    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Remove ${beneficiary.name}?',
      details: [
        ConfirmationDetail(label: 'Bank', value: beneficiary.bank),
        ConfirmationDetail(label: 'Account', value: beneficiary.maskedNumber),
      ],
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      await ref.read(beneficiaryServiceProvider).remove(beneficiary.id);
      ref.invalidate(beneficiariesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${beneficiary.name} removed')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Beneficiary beneficiary) async {
    await ref.read(beneficiaryServiceProvider).toggleFavorite(beneficiary.id);
    ref.invalidate(beneficiariesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(beneficiary.isFavorite ? 'Removed from favorites' : 'Added to favorites')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final beneficiariesAsync = ref.watch(beneficiariesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Beneficiaries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: AppColors.primary),
            onPressed: _addBeneficiary,
          ),
        ],
      ),
      body: SafeArea(
        child: beneficiariesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                SkeletonBalanceCard(),
                SizedBox(height: 16),
                SkeletonActionRow(count: 3),
              ],
            ),
          ),
          error: (_, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.destructive, size: 40),
                const SizedBox(height: 16),
                Text('Unable to load beneficiaries', style: context.typography.headline),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Retry',
                  onPressed: () => ref.invalidate(beneficiariesProvider),
                ),
              ],
            ),
          ),
          data: (beneficiaries) {
            if (beneficiaries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_outline, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text('No beneficiaries yet', style: context.typography.headline),
                    const SizedBox(height: 8),
                    Text('Add people you send money to often', style: context.typography.bodyMedium),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Add Beneficiary',
                      onPressed: _addBeneficiary,
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: beneficiaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = beneficiaries[index];
                return _BeneficiaryTile(
                  beneficiary: b,
                  onTap: () => context.push('/profile/beneficiaries/${b.id}', extra: b),
                  onToggleFavorite: () => _toggleFavorite(b),
                  onRemove: () => _removeBeneficiary(b),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BeneficiaryTile extends StatelessWidget {
  const _BeneficiaryTile({
    required this.beneficiary,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onRemove,
  });

  final Beneficiary beneficiary;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedPress(
      scaleFactor: 0.98,
      onTap: onTap,
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
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: beneficiary.isFavorite ? AppColors.warningMuted : AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              beneficiary.isFavorite ? Icons.star : Icons.person,
              color: beneficiary.isFavorite ? AppColors.warning : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(beneficiary.name, style: context.typography.labelLarge),
                    if (beneficiary.isFavorite) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.star, color: AppColors.warning, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${beneficiary.bank} • ${beneficiary.maskedNumber}', style: context.typography.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textTertiary),
            onSelected: (value) {
              if (value == 'favorite') onToggleFavorite();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'favorite',
                child: Text(beneficiary.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove', style: TextStyle(color: AppColors.destructive)),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}