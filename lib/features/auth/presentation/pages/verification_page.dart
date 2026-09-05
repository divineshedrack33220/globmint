import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/pin_input.dart';

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key, this.email});

  final String? email;

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  bool _isLoading = false;
  String? _error;

  String get _email {
    final raw = widget.email?.trim() ?? '';
    if (raw.isNotEmpty) return raw;
    return ref.read(authServiceProvider).currentUser?.email ?? '';
  }

  String get _maskedEmail {
    final email = _email;
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at + 1);
    final maskedLocal = local.length > 3
        ? '${local.substring(0, 3)}••••'
        : '${local.substring(0, 1)}••';
    return '$maskedLocal@$domain';
  }

  void _handleComplete(String pin) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isLoading = false);
      context.push('/create-pin');
    }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('Verify your email', style: context.typography.display),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to your email',
                style: context.typography.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _maskedEmail,
                style: context.typography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 40),
              PinInput(
                length: 6,
                onCompleted: _handleComplete,
                errorText: _error,
              ),
              const Spacer(),
              AppButton(
                text: 'Verify',
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (!context.mounted) return;
                  setState(() => _isLoading = false);
                  context.push('/create-pin');
                },
                isLoading: _isLoading,
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('A new code has been sent')),
                    );
                  },
                  child: Text(
                    'Resend code',
                    style: context.typography.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
