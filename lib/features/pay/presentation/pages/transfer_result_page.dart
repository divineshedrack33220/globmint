import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';

enum TransferResultType { success, processing, failed }

class TransferResultPage extends StatelessWidget {
  const TransferResultPage({
    super.key,
    this.type = TransferResultType.success,
    this.amount,
    this.accountName,
  });

  final TransferResultType type;
  final double? amount;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final a = amount ?? 0;
    final isSuccess = type == TransferResultType.success;
    final icon = isSuccess ? Icons.check : (type == TransferResultType.processing ? Icons.hourglass_top : Icons.error_outline);
    final color = isSuccess ? AppColors.success : (type == TransferResultType.processing ? AppColors.primary : AppColors.destructive);
    final muted = isSuccess ? AppColors.successMuted : (type == TransferResultType.processing ? AppColors.primaryMuted : AppColors.destructiveMuted);
    final title = isSuccess ? 'Transfer Successful' : (type == TransferResultType.processing ? 'Processing Transfer' : 'Transfer Failed');
    final subtitle = isSuccess
        ? 'Sent to ${accountName ?? 'Beneficiary'}'
        : (type == TransferResultType.processing
            ? 'Your transfer is being processed. You\u2019ll see it shortly.'
            : 'Something went wrong. Your money was not deducted.');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 44),
              ),
              const SizedBox(height: 24),
              Text(title, style: context.typography.headline),
              const SizedBox(height: 8),
              Text(CurrencyFormatter.ngn(a), style: context.typography.amountHeroHighlight),
              const SizedBox(height: 8),
              Text(subtitle, style: context.typography.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 40),
              if (type == TransferResultType.processing)
                AppButton(
                  text: 'Track Activity',
                  onPressed: () => context.go('/activity'),
                  isExpanded: true,
                )
              else
                AppButton(
                  text: 'Done',
                  onPressed: () => context.go('/home'),
                  isExpanded: true,
                ),
              if (type == TransferResultType.failed) ...[
                const SizedBox(height: 12),
                AppButton(
                  text: 'Try Again',
                  onPressed: () => context.go('/pay'),
                  isExpanded: true,
                  variant: AppButtonVariant.secondary,
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
