import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/radius_tokens.dart';
import '../theme/theme_extensions.dart';
import 'app_button.dart';

class ConfirmationModal extends StatelessWidget {
  const ConfirmationModal({
    super.key,
    required this.title,
    this.description,
    required this.details,
    required this.confirmText,
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final String title;
  final String? description;
  final List<ConfirmationDetail> details;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isLoading;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String? description,
    required List<ConfirmationDetail> details,
    required String confirmText,
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => ConfirmationModal(
        title: title,
        description: description,
        details: details,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDestructive: isDestructive,
        isLoading: isLoading,
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
        // Keep the dialog within the screen so the action buttons never get
        // clipped off-screen, and scroll long content instead of overflowing.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: context.typography.headline,
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: context.typography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: details.map((detail) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            detail.label,
                            style: context.typography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              detail.value,
                              style: context.typography.labelLarge.copyWith(
                                color: detail.isHighlighted
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: confirmText,
                onPressed: onConfirm,
                variant: isDestructive
                    ? AppButtonVariant.destructive
                    : AppButtonVariant.primary,
                isExpanded: true,
                isLoading: isLoading,
              ),
              const SizedBox(height: 12),
              AppButton(
                text: cancelText,
                onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                variant: AppButtonVariant.text,
                isExpanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfirmationDetail {
  final String label;
  final String value;
  final bool isHighlighted;

  const ConfirmationDetail({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });
}
