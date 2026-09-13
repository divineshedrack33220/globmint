import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/pin_input.dart';
import '../../../../shared/services/api_client.dart';

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key, this.email, this.initialResendAfterMs});

  final String? email;

  /// Unix-ms deadline (from the register response) before which a fresh code
  /// may NOT be requested. When set, the page skips the auto-send on open
  /// because the code was already delivered during registration.
  final int? initialResendAfterMs;

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    if (_email.isNotEmpty) {
      final deadline = widget.initialResendAfterMs;
      if (deadline != null && deadline > DateTime.now().millisecondsSinceEpoch) {
        // A code was already emailed during registration; just reflect the
        // cooldown instead of firing a second send (which the backend would
        // reject with TOO_MANY_REQUESTS).
        _startResendCountdown(untilMs: deadline);
      } else {
        // Deliver a fresh code as soon as the page opens.
        _sendOtp();
      }
    } else {
      _error = 'No email to verify. Please start again.';
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

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

  String _code = '';

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).sendOtp(_email);
      _startResendCountdown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the code. Try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startResendCountdown({int? untilMs}) {
    _resendTimer?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = untilMs == null
        ? 60
        : ((untilMs - now) / 1000).ceil().clamp(0, 60);
    setState(() => _resendIn = remaining);
    if (_resendIn <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _verify(String code) async {
    if (code.length != 6) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authServiceProvider).verifyOtp(_email, code);
      if (!mounted) return;
      if (!result.verified) {
        setState(() {
          _isLoading = false;
          _error = 'Could not verify this code. Try again.';
        });
        return;
      }
      setState(() => _isLoading = false);
      context.push('/create-pin');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
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
                onChanged: (v) => _code = v,
                onCompleted: _verify,
                errorText: _error,
              ),
              const Spacer(),
              AppButton(
                text: _isSending ? 'Sending code…' : 'Verify',
                onPressed: _code.length == 6 ? () => _verify(_code) : null,
                isLoading: _isLoading,
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resendIn > 0 || _isSending
                      ? null
                      : () {
                          _resendTimer?.cancel();
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          _sendOtp();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('A new code has been sent')),
                          );
                        },
                  child: Text(
                    _resendIn > 0 ? 'Resend code (${_resendIn}s)' : 'Resend code',
                    style: context.typography.labelMedium.copyWith(
                      color: _resendIn > 0
                          ? AppColors.textDisabled
                          : AppColors.primary,
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
