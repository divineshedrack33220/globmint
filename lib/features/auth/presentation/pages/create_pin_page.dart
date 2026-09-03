import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/pin_input.dart';

class CreatePinPage extends StatefulWidget {
  const CreatePinPage({super.key});

  @override
  State<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
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

  void _handleConfirmPin(String pin) async {
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
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/home');
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
