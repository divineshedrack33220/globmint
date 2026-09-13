import 'package:flutter/material.dart';
import '../enums/transaction_type.dart';
import '../theme/app_colors.dart';

/// Icon + colors per transaction type. Shared by the home recent-activity
/// list, the activity page, and the savings history so all three always
/// agree (e.g. deposit = green, withdrawal = red).
(IconData, Color, Color) transactionStyle(TransactionType type) {
  switch (type) {
    case TransactionType.deposit:
      return (Icons.arrow_downward, AppColors.success, AppColors.successMuted);
    case TransactionType.withdrawal:
      return (
        Icons.arrow_upward,
        AppColors.destructive,
        AppColors.destructiveMuted,
      );
    case TransactionType.conversion:
      return (Icons.currency_exchange, AppColors.primary, AppColors.primarySubtle);
    case TransactionType.transfer:
      return (Icons.send, AppColors.info, AppColors.infoMuted);
    case TransactionType.savings:
      return (Icons.savings, AppColors.primary, AppColors.primarySubtle);
    case TransactionType.fee:
      return (Icons.receipt, AppColors.warning, AppColors.warningMuted);
    case TransactionType.adjustment:
      return (Icons.tune, AppColors.info, AppColors.infoMuted);
    case TransactionType.reversal:
      return (Icons.swap_horiz, AppColors.destructive, AppColors.destructiveMuted);
  }
}