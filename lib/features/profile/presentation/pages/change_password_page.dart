import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/success_dialog.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _loading = false);
      await SuccessDialog.show(
        context: context,
        type: SuccessDialogType.success,
        title: 'Password changed',
        amount: '✓',
        subtitle: 'Your password has been updated successfully.',
        onPressed: () => context.pop(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Update your password', style: context.typography.display),
                const SizedBox(height: 8),
                Text(
                  'Use at least 8 characters with a mix of letters and numbers',
                  style: context.typography.bodyMedium,
                ),
                const SizedBox(height: 32),
                PasswordTextField(
                  controller: _currentController,
                  label: 'Current password',
                  hint: 'Enter current password',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your current password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                PasswordTextField(
                  controller: _newController,
                  label: 'New password',
                  hint: 'Enter new password',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a new password';
                    if (v.length < 8) return 'Use at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                PasswordTextField(
                  controller: _confirmController,
                  label: 'Confirm new password',
                  hint: 'Re-enter new password',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your new password';
                    if (v != _newController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Update Password',
                  onPressed: _submit,
                  isLoading: _loading,
                  isExpanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
