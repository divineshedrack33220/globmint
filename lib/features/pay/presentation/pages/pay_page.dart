import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';

/// Vault payout hub: shows the on-chain vault holdings and routes every
/// payout through the vault — deposit USDC in, or withdraw USDC out to any
/// address.
class PayPage extends ConsumerWidget {
  const PayPage({super.key});

  static final _numReg = RegExp(r'^\s*([\d.]+)');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultStatusProvider).valueOrNull;
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final rate = summary?.currentRate ?? 0;

    final rawBalance = vault?.vaultUsdcBalance ?? '0.000000 USDC';
    final match = _numReg.firstMatch(rawBalance);
    final usdc = match == null || match.group(1) == null
        ? 0.0
        : double.tryParse(match.group(1)!) ?? 0.0;
    final vaultNgn = usdc * rate;

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
              // Vault balance hero
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
                      'VAULT BALANCE',
                      style: context.typography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(rawBalance, style: context.typography.amountHero),
                    const SizedBox(height: 4),
                    Text(
                      '≈ ${CurrencyFormatter.ngn(vaultNgn)}',
                      style: context.typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1 USDC = ${CurrencyFormatter.ngn(rate)}',
                      style: context.typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Payout actions
              Text('Payouts', style: context.typography.title),
              const SizedBox(height: 16),
              _PayoutAction(
                icon: Icons.send,
                title: 'Withdraw USDC',
                subtitle: 'Send USDC from your vault to any address',
                onTap: () => context.push('/savings/withdraw'),
              ),
              const SizedBox(height: 12),
              _PayoutAction(
                icon: Icons.account_balance_wallet,
                title: 'Deposit USDC',
                subtitle: 'Top up your vault with USDC on-chain',
                onTap: () => context.push('/savings/add-money'),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All payouts are made from your on-chain vault and settled in USDC.',
                        style: context.typography.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutAction extends StatelessWidget {
  const _PayoutAction({
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