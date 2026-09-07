import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/radius_tokens.dart';
import 'animated_press.dart';

enum AppButtonVariant { primary, secondary, destructive, text, icon }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.isEnabled = true,
    this.height = 56,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final bool isEnabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (isLoading || !isEnabled) ? null : onPressed;

    final button = switch (variant) {
      AppButtonVariant.primary => _buildPrimary(context, effectiveOnPressed),
      AppButtonVariant.secondary => _buildSecondary(context, effectiveOnPressed),
      AppButtonVariant.destructive => _buildDestructive(context, effectiveOnPressed),
      AppButtonVariant.text => _buildText(context, effectiveOnPressed),
      AppButtonVariant.icon => _buildIcon(context, effectiveOnPressed),
    };

    return AnimatedPress(
      onTap: effectiveOnPressed,
      child: button,
    );
  }

  Widget _buildPrimary(BuildContext context, VoidCallback? onPressed) {
    return SizedBox(
      height: height,
      width: isExpanded ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          shadowColor: AppColors.primaryHighlight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: _buildChild(context, AppColors.textOnPrimary),
      ),
    );
  }

  Widget _buildSecondary(BuildContext context, VoidCallback? onPressed) {
    return SizedBox(
      height: height,
      width: isExpanded ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(
            color: onPressed != null ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: _buildChild(context, AppColors.primary),
      ),
    );
  }

  Widget _buildDestructive(BuildContext context, VoidCallback? onPressed) {
    return SizedBox(
      height: height,
      width: isExpanded ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.destructive,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: _buildChild(context, Colors.white),
      ),
    );
  }

  Widget _buildText(BuildContext context, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textDisabled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: _buildChild(context, AppColors.primary),
    );
  }

  Widget _buildIcon(BuildContext context, VoidCallback? onPressed) {
    return SizedBox(
      height: 48,
      width: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.textPrimary, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context, Color textColor) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }
    if (icon != null && variant != AppButtonVariant.icon) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }
    return Text(text);
  }
}
