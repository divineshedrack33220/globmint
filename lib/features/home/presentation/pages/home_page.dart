import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/account.dart';
import '../../../../shared/models/models.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/savings_summary_card.dart';
import '../widgets/recent_transactions_list.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // Balance/vault/transaction updates are pushed over SSE via
  // ScaffoldWithNavBar; the dashboard needs no local polling timer.

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: context.typography.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userAsync.maybeWhen(
                        data: (u) => u.firstName,
                        orElse: () => '...',
                      ),
                      style: context.typography.headline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Balance hero / loading / error
              summaryAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _BalanceSkeleton(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: BalanceCard(
                    label: 'TOTAL SAVINGS',
                    amount: '₦0.00',
                    subtitle: 'Unable to load balance',
                    isHero: true,
                  ),
                ),
                data: (summary) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _BalanceSection(summary: summary),
                ),
              ),
              const SizedBox(height: 16),
              // Available Balance
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _AvailableBalanceCard(summaryAsync: summaryAsync),
              ),
              const SizedBox(height: 24),
              // On-chain vault status
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _VaultStatusCard(),
              ),
              const SizedBox(height: 24),
              // Quick Actions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: QuickActionsRow(),
              ),
              const SizedBox(height: 24),
              // Savings Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SavingsSummaryCard(summaryAsync: summaryAsync),
              ),
              const SizedBox(height: 24),
              // Recent Transactions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: RecentTransactionsList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceSection extends ConsumerWidget {
  const _BalanceSection({required this.summary});
  final AccountSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultStatusProvider).valueOrNull;
    final vaultUsdc = vault == null ? 0.0 : CurrencyFormatter.vaultUsdc(vault.vaultUsdcBalance);
    final rate = summary.currentRate;
    final nairaBase = summary.totalNgnEquivalent;
    final vaultNgn = vaultUsdc * rate;
    final totalNgn = nairaBase + vaultNgn;

    return BalanceCard(
      label: 'TOTAL ASSETS',
      amount: CurrencyFormatter.ngn(totalNgn),
      subtitle:
          '${CurrencyFormatter.ngn(nairaBase)} + on-chain ${_fmtUsdc(vaultUsdc)} vault ≈ ${CurrencyFormatter.ngn(vaultNgn)}',
      isHero: true,
    );
  }

  String _fmtUsdc(double v) =>
      '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)} USDC';
}

class _AvailableBalanceCard extends StatelessWidget {
  const _AvailableBalanceCard({required this.summaryAsync});
  final AsyncValue<AccountSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final available = summary?.available;
    final currentRate = summary?.currentRate ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Balance', style: context.typography.labelMedium),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.ngn(available?.balance ?? 0),
                style: context.typography.amountMedium,
              ),
            ],
          ),
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exchange Rate', style: context.typography.labelMedium),
              const SizedBox(height: 4),
              Text(
                '₦${currentRate.toStringAsFixed(2)}',
                style: context.typography.amountMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live on-chain vault summary: the deposit address, the network it is on, and
/// the USDC balance currently held on-chain by the vault.
class _VaultStatusCard extends ConsumerWidget {
  const _VaultStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(vaultStatusProvider);
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final rate = summary?.currentRate ?? 0;

    return status.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (v) {
        if (!v.hasAddress) return const SizedBox.shrink();
        final balance = v.vaultUsdcBalance;
        final usdc = CurrencyFormatter.vaultUsdc(balance);
        final vaultNgn = usdc * rate;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('On-chain vault', style: context.typography.labelMedium),
                  const Spacer(),
                  _NetworkChip(network: v.network),
                ],
              ),
              const SizedBox(height: 12),
              Text('Vault USDC balance',
                  style: context.typography.bodySmall),
              const SizedBox(height: 2),
              Text(balance, style: context.typography.amountMedium),
              const SizedBox(height: 2),
              Text(
                '≈ ${CurrencyFormatter.ngn(vaultNgn)}',
                style: context.typography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                '1 USDC = ${CurrencyFormatter.ngn(rate)}',
                style: context.typography.bodySmall
                    .copyWith(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text('Deposit address', style: context.typography.bodySmall),
              const SizedBox(height: 2),
              SelectableText(
                v.address,
                style: context.typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({required this.network});
  final String network;

  @override
  Widget build(BuildContext context) {
    final label = network.isEmpty ? 'Unknown' : network;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.typography.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
