import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/pin_input.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../shared/services/api_client.dart';

class ChangePinPage extends ConsumerStatefulWidget {
  const ChangePinPage({super.key});

  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

enum _PinStep { current, newPin, confirm }

class _ChangePinPageState extends ConsumerState<ChangePinPage> {
  _PinStep _step = _PinStep.current;
  String? _error;
  String? _newPin;
  String? _currentPin;
  bool _loading = false;

  String get _title => switch (_step) {
        _PinStep.current => 'Enter current PIN',
        _PinStep.newPin => 'Enter new PIN',
        _PinStep.confirm => 'Confirm new PIN',
      };

  String get _subtitle => switch (_step) {
        _PinStep.current => 'Verify it\u2019s you before changing your PIN',
        _PinStep.newPin => 'Choose a new 6-digit PIN',
        _PinStep.confirm => 'Re-enter your new PIN',
      };

  Future<void> _handleCurrentPin(String pin) async {
    if (pin.length < 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifyPin(pin);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _currentPin = pin;
        _step = _PinStep.newPin;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not verify your current PIN. Try again.';
      });
    }
  }

  void _handleNewPin(String pin) {
    if (pin.length < 6) return;
    setState(() {
      _newPin = pin;
      _step = _PinStep.confirm;
      _error = null;
    });
  }

  Future<void> _handleConfirmPin(String pin) async {
    if (pin != _newPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _step = _PinStep.newPin;
        _newPin = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .setPin(pin: pin, currentPin: _currentPin);
      if (!mounted) return;
      setState(() => _loading = false);
      await SuccessDialog.show(
        context: context,
        type: SuccessDialogType.success,
        title: 'PIN changed',
        amount: '●●●●●●',
        subtitle: 'Your transaction PIN has been updated.',
        onPressed: () => context.pop(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not update your PIN. Try again.';
      });
    }
  }

  Widget _buildPinInput() {
    return Center(
      child: PinInput(
        key: ValueKey('$_step-$_error'),
        length: 6,
        errorText: _error,
        onCompleted: switch (_step) {
          _PinStep.current => _handleCurrentPin,
          _PinStep.newPin => _handleNewPin,
          _PinStep.confirm => _handleConfirmPin,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(_title, style: context.typography.display),
              const SizedBox(height: 8),
              Text(_subtitle, style: context.typography.bodyMedium),
              const SizedBox(height: 40),
              _buildPinInput(),
              const Spacer(),
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
}
