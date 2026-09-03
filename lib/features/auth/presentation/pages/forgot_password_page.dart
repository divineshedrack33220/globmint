import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/pin_input.dart';
import '../../../../core/widgets/success_dialog.dart';

enum _ResetStep { email, code, password }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _loading = false;
  String? _pinError;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _title => switch (_step) {
        _ResetStep.email => 'Reset password',
        _ResetStep.code => 'Enter code',
        _ResetStep.password => 'New password',
      };

  String get _subtitle => switch (_step) {
        _ResetStep.email => 'Enter your email to receive a reset code',
        _ResetStep.code => 'Enter the 6-digit code sent to your email',
        _ResetStep.password => 'Choose a new password to secure your account',
      };

  String get _maskedEmail {
    final email = _emailController.text.trim();
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at + 1);
    final maskedLocal = local.length > 3
        ? '${local.substring(0, 3)}••••'
        : '${local.substring(0, 1)}••';
    return '$maskedLocal@$domain';
  }

  void _handleSendCode() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _ResetStep.code;
      });
    });
  }

  void _handleCode(String code) async {
    setState(() {
      _loading = true;
      _pinError = null;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _loading = false;
        _step = _ResetStep.password;
      });
    }
  }

  void _handleReset() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      setState(() => _loading = false);
      await SuccessDialog.show(
        context: context,
        type: SuccessDialogType.success,
        title: 'Password reset',
        amount: '✓',
        subtitle: 'Your password has been updated. Sign in to continue.',
        onPressed: () => context.go('/login'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(_title, style: context.typography.display),
              const SizedBox(height: 8),
              Text(_subtitle, style: context.typography.bodyMedium),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(),
              ),
              const SizedBox(height: 32),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _ResetStep.email:
        return Form(
          key: _formKey,
          child: Column(
            key: const ValueKey('email'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _emailController,
                label: 'Email address',
                hint: 'emeka@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Send Reset Code',
                onPressed: _handleSendCode,
                isExpanded: true,
                isLoading: _loading,
              ),
            ],
          ),
        );
      case _ResetStep.code:
        return Column(
          key: const ValueKey('code'),
          children: [
            Text(
              _maskedEmail,
              style: context.typography.labelLarge.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 32),
            PinInput(length: 6, onCompleted: _handleCode, errorText: _pinError),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A new code has been sent')),
                  );
                },
                child: Text(
                  'Resend code',
                  style: context.typography.labelMedium.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
        );
      case _ResetStep.password:
        return Form(
          key: _formKey,
          child: Column(
            key: const ValueKey('password'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PasswordTextField(
                controller: _newPasswordController,
                label: 'New password',
                hint: 'At least 8 characters',
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
                  if (v == null || v.isEmpty) return 'Confirm your password';
                  if (v != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Reset Password',
                onPressed: _handleReset,
                isExpanded: true,
                isLoading: _loading,
              ),
            ],
          ),
        );
    }
  }
}
