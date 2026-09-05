import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';
import '../../shared/services/api_client.dart';
import 'pin_input.dart';

/// Prompts the user for their 6-digit transaction PIN and verifies it against
/// [`onVerify`] before returning the confirmed PIN. Returns the PIN string on
/// success, or `null` if the sheet was dismissed.
Future<String?> showPinVerifySheet(
  BuildContext context, {
  String title = 'Enter your PIN',
  String subtitle = 'Verify it\u2019s you before sending',
  required Future<void> Function(String pin) onVerify,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: _PinVerifySheet(
        title: title,
        subtitle: subtitle,
        onVerify: onVerify,
      ),
    ),
  );
}

class _PinVerifySheet extends StatefulWidget {
  const _PinVerifySheet({
    required this.title,
    required this.subtitle,
    required this.onVerify,
  });

  final String title;
  final String subtitle;
  final Future<void> Function(String pin) onVerify;

  @override
  State<_PinVerifySheet> createState() => _PinVerifySheetState();
}

class _PinVerifySheetState extends State<_PinVerifySheet> {
  String? _error;
  bool _loading = false;

  Future<void> _handlePin(String pin) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onVerify(pin);
      if (mounted) Navigator.of(context).pop(pin);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not verify PIN. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.title, style: context.typography.display),
            const SizedBox(height: 8),
            Text(widget.subtitle, style: context.typography.bodyMedium),
            const SizedBox(height: 28),
            Center(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : PinInput(
                      key: ValueKey(_error),
                      length: 6,
                      errorText: _error,
                      onCompleted: _handlePin,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}