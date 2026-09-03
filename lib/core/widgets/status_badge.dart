import 'package:flutter/material.dart';
import '../enums/transaction_status.dart';
import '../theme/app_colors.dart';
import '../theme/radius_tokens.dart';
import '../theme/theme_extensions.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.size = StatusBadgeSize.medium,
  });

  final TransactionStatus status;
  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == StatusBadgeSize.small ? 6 : 10,
        vertical: size == StatusBadgeSize.small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size == StatusBadgeSize.small ? 4 : 6,
            height: size == StatusBadgeSize.small ? 4 : 6,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: size == StatusBadgeSize.small ? 4 : 6),
          Text(
            status.label,
            style: (size == StatusBadgeSize.small
                    ? context.typography.labelSmall
                    : context.typography.labelMedium)
                .copyWith(color: config.color),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getConfig() {
    switch (status) {
      case TransactionStatus.completed:
        return _StatusConfig(AppColors.success, AppColors.successMuted);
      case TransactionStatus.processing:
        return _StatusConfig(AppColors.warning, AppColors.warningMuted);
      case TransactionStatus.initiated:
        return _StatusConfig(AppColors.primary, AppColors.primaryMuted);
      case TransactionStatus.failed:
        return _StatusConfig(AppColors.destructive, AppColors.destructiveMuted);
      case TransactionStatus.cancelled:
      case TransactionStatus.reversed:
        return _StatusConfig(AppColors.textTertiary, AppColors.border);
    }
  }
}

enum StatusBadgeSize { small, medium }

class _StatusConfig {
  final Color color;
  final Color backgroundColor;
  const _StatusConfig(this.color, this.backgroundColor);
}
