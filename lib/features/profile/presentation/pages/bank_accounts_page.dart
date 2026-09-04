import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../shared/models/bank_account.dart';

class BankAccountsPage extends ConsumerStatefulWidget {
  const BankAccountsPage({super.key});

  @override
  ConsumerState<BankAccountsPage> createState() => _BankAccountsPageState();
}

class _BankAccountsPageState extends ConsumerState<BankAccountsPage> {
  Future<void> _addAccount() async {
    final formKey = GlobalKey<FormState>();
    final bankNameController = TextEditingController();
    final bankCodeController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();
    final isDefaultController = ValueNotifier(false);

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
          title: Text('Add Bank Account', style: context.typography.headline),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: bankNameController,
                    label: 'Bank Name',
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: bankCodeController,
                    label: 'Bank Code (3 digits)',
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.length != 3 ? '3 digits' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: accountNumberController,
                    label: 'Account Number (10 digits)',
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.length != 10 ? '10 digits' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: accountNameController,
                    label: 'Account Name',
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isDefaultController.value,
                        onChanged: (v) => setState(() => isDefaultController.value = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                      Text('Set as default', style: context.typography.bodyMedium),
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
                    'bankName': bankNameController.text.trim(),
                    'bankCode': bankCodeController.text.trim(),
                    'accountNumber': accountNumberController.text.trim(),
                    'accountName': accountNameController.text.trim(),
                    'isDefault': isDefaultController.value,
                  });
                }
              },
            ),
          ],
        ),
      ),
    );

    if (result is Map<String, dynamic>) {
      await ref.read(bankAccountServiceProvider).create(
            bankName: result['bankName'] as String,
            bankCode: result['bankCode'] as String,
            accountNumber: result['accountNumber'] as String,
            accountName: result['accountName'] as String,
            isDefault: result['isDefault'] as bool,
          );
      ref.invalidate(bankAccountsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account added')),
        );
      }
    }
  }

  Future<void> _removeAccount(BankAccount account) async {
    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Remove ${account.bankName}?',
      details: [
        ConfirmationDetail(label: 'Account', value: account.maskedNumber),
        ConfirmationDetail(label: 'Name', value: account.accountName),
      ],
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      await ref.read(bankAccountServiceProvider).remove(account.id);
      ref.invalidate(bankAccountsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${account.bankName} removed')),
        );
      }
    }
  }

  Future<void> _setDefault(BankAccount account) async {
    await ref.read(bankAccountServiceProvider).setDefault(account.id);
    ref.invalidate(bankAccountsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.bankName} set as default')),
      );
    }
  }

  void _showAccountDetails(BankAccount account) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: account.isDefault ? AppColors.primaryMuted : AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(12),
                      border: account.isDefault ? Border.all(color: AppColors.primary, width: 2) : null,
                    ),
                    child: Icon(
                      Icons.account_balance,
                      color: account.isDefault ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.bankName, style: context.typography.title),
                        if (account.isDefault)
                          Text('Default account', style: context.typography.labelSmall.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DetailRow(label: 'Account Name', value: account.accountName),
              _DetailRow(label: 'Account Number', value: account.accountNumber),
              _DetailRow(label: 'Bank Code', value: account.bankCode),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: account.isDefault ? 'Default' : 'Set Default',
                      onPressed: account.isDefault
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                              _setDefault(account);
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'Remove',
                      variant: AppButtonVariant.destructive,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _removeAccount(account);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(bankAccountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bank Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: _addAccount,
          ),
        ],
      ),
      body: SafeArea(
        child: accountsAsync.when(
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
                Text('Unable to load bank accounts', style: context.typography.headline),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Retry',
                  onPressed: () => ref.invalidate(bankAccountsProvider),
                ),
              ],
            ),
          ),
          data: (accounts) {
            if (accounts.isEmpty) {
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
                      child: const Icon(Icons.account_balance, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text('No bank accounts yet', style: context.typography.headline),
                    const SizedBox(height: 8),
                    Text('Add your first account to withdraw easily', style: context.typography.bodyMedium),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Add Bank Account',
                      onPressed: _addAccount,
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _BankAccountTile(
                  account: account,
                  onTap: () => _showAccountDetails(account),
                  onSetDefault: () => _setDefault(account),
                  onRemove: () => _removeAccount(account),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BankAccountTile extends StatelessWidget {
  const _BankAccountTile({
    required this.account,
    required this.onTap,
    required this.onSetDefault,
    required this.onRemove,
  });

  final BankAccount account;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;
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
              color: account.isDefault ? AppColors.primaryMuted : AppColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(12),
              border: account.isDefault ? Border.all(color: AppColors.primary, width: 2) : null,
            ),
            child: Icon(
              Icons.account_balance,
              color: account.isDefault ? AppColors.primary : AppColors.textSecondary,
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
                    Text(account.bankName, style: context.typography.labelLarge),
                    if (account.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('DEFAULT', style: context.typography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 9,
                        )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(account.maskedNumber, style: context.typography.bodySmall),
                Text(account.accountName, style: context.typography.labelSmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textTertiary),
            onSelected: (value) {
              if (value == 'default') onSetDefault();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'default',
                enabled: !account.isDefault,
                child: Text(account.isDefault ? 'Default account' : 'Set as default'),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.typography.bodyMedium),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: context.typography.labelLarge,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}