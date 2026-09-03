import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';
import 'app_button.dart';

enum ErrorType { network, generic, auth, service }

class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({
    super.key,
    this.type = ErrorType.generic,
    this.message,
    this.onRetry,
    this.retryText = 'Try Again',
  });

  final ErrorType type;
  final String? message;
  final VoidCallback? onRetry;
  final String retryText;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: config.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: config.iconColor, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              config.title,
              style: context.typography.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? config.description,
              style: context.typography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              AppButton(
                text: retryText,
                onPressed: onRetry,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ErrorConfig _getConfig() {
    switch (type) {
      case ErrorType.network:
        return _ErrorConfig(
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.textTertiary,
          backgroundColor: AppColors.surface,
          title: 'No Internet Connection',
          description: 'Please check your network settings and try again.',
        );
      case ErrorType.generic:
        return _ErrorConfig(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.warning,
          backgroundColor: AppColors.warningMuted,
          title: 'Something Went Wrong',
          description: 'An unexpected error occurred. Please try again.',
        );
      case ErrorType.auth:
        return _ErrorConfig(
          icon: Icons.lock_outline_rounded,
          iconColor: AppColors.destructive,
          backgroundColor: AppColors.destructiveMuted,
          title: 'Session Expired',
          description: 'Your session has expired. Please log in again.',
        );
      case ErrorType.service:
        return _ErrorConfig(
          icon: Icons.build_outlined,
          iconColor: AppColors.textTertiary,
          backgroundColor: AppColors.surface,
          title: 'Service Unavailable',
          description: 'The service is temporarily unavailable. Please try again later.',
        );
    }
  }
}

class _ErrorConfig {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String description;

  const _ErrorConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.description,
  });
}

class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.destructiveMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.destructive, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.typography.bodySmall.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: context.typography.labelSmall.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
