import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/pin_input.dart';
import '../../../../shared/services/api_client.dart';

class CreatePinPage extends ConsumerStatefulWidget {
  const CreatePinPage({super.key});

  @override
  ConsumerState<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends ConsumerState<CreatePinPage> {
  String? _error;
  bool _isLoading = false;
  bool _isConfirming = false;
  String? _firstPin;

  void _handleFirstPin(String pin) {
    setState(() {
      _firstPin = pin;
      _isConfirming = true;
      _error = null;
    });
  }

  Future<void> _handleConfirmPin(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _error = 'PINs do not match. Please try again.';
        _isConfirming = false;
        _firstPin = null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).setPin(pin: pin);
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
        _isConfirming = false;
        _firstPin = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not save your PIN. Please try again.';
        _isConfirming = false;
        _firstPin = null;
      });
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
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Create a PIN',
                style: context.typography.display,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Re-enter your 6-digit PIN to confirm'
                    : 'This will be used to secure your transactions',
                style: context.typography.bodyMedium,
              ),
              const SizedBox(height: 40),
              Center(
                child: PinInput(
                  key: ValueKey(_isConfirming),
                  length: 6,
                  onCompleted: _isConfirming ? _handleConfirmPin : _handleFirstPin,
                  errorText: _error,
                ),
              ),
              const Spacer(),
              if (_isLoading)
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
}
