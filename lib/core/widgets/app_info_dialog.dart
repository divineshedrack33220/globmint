import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/radius_tokens.dart';
import '../theme/theme_extensions.dart';
import 'app_button.dart';

/// On-demand informational dialog: a titled modal that appears only when the
/// user asks for details, keeping primary screens from being buried in prose.
class InfoDialog extends StatelessWidget {
  const InfoDialog({
    super.key,
    required this.title,
    this.icon,
    required this.body,
    this.confirmText = 'Got it',
  });

  final String title;
  final IconData? icon;
  final List<Widget> body;
  final String confirmText;

  static Future<void> show({
    required BuildContext context,
    required String title,
    IconData? icon,
    required List<Widget> body,
    String confirmText = 'Got it',
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => InfoDialog(
        title: title,
        icon: icon,
        body: body,
        confirmText: confirmText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: ConstrainedBox(
        // Keep the dialog within the screen and scroll long content instead
        // of overflowing, mirroring the confirmation modal behaviour.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: 40),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                style: context.typography.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ...body,
              const SizedBox(height: 24),
              AppButton(
                text: confirmText,
                onPressed: () => Navigator.of(context).pop(),
                isExpanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}