import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';

class PayPage extends ConsumerWidget {
  const PayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(accountSummaryProvider).valueOrNull?.available.balance ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pay', style: context.typography.display),
              const SizedBox(height: 24),
              // Available Balance
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABLE BALANCE',
                      style: context.typography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.ngn(available),
                      style: context.typography.amountHero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Transfer Options
              Text('Transfer Options', style: context.typography.title),
              const SizedBox(height: 16),
              _TransferOption(
                icon: Icons.account_balance,
                title: 'Bank Transfer',
                subtitle: 'Send money to any Nigerian bank account',
                onTap: () => context.push('/pay/bank-transfer'),
              ),
              const SizedBox(height: 12),
              _TransferOption(
                icon: Icons.person,
                title: 'Send to Beneficiary',
                subtitle: 'Send to a saved beneficiary',
                onTap: () => context.push('/pay/send-beneficiary'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferOption extends StatelessWidget {
  const _TransferOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.typography.labelLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.typography.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
