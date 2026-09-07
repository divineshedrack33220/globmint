import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/account.dart';
import '../../../../shared/models/models.dart';
import '../widgets/announcement_slot.dart';
import '../widgets/balance_card.dart';
import '../widgets/currency_flag_selector.dart';
import '../widgets/pending_lock_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/rate_sparkline_card.dart';
import '../widgets/recent_transactions_list.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // Balance/vault/transaction updates are pushed over SSE via
  // ScaffoldWithNavBar; the dashboard needs no local polling timer.
  bool _obscured = false;
  DisplayCurrency _displayCurrency = DisplayCurrency.ngn;
  DateTime? _lastUpdated;
  Timer? _ageTimer;

  @override
  void initState() {
    super.initState();
    // Repaints the "updated … ago" freshness text as it ages.
    _ageTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    super.dispose();
  }

  void _stamp() {
    _lastUpdated = DateTime.now();
  }

  String get _freshness {
    final at = _lastUpdated;
    if (at == null) return '';
    return formatAge(at);
  }

  Future<void> _refresh() async {
    ref.invalidate(accountSummaryProvider);
    ref.invalidate(vaultStatusProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(pendingElevationsProvider);
    ref.invalidate(depositInfoProvider);
    try {
      await Future.wait([
        ref.read(accountSummaryProvider.future),
        ref.read(vaultStatusProvider.future),
        ref.read(transactionsProvider.future),
        ref.read(pendingElevationsProvider.future),
      ]);
    } catch (_) {
      // Individual providers surface their own error states.
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final userAsync = ref.watch(currentUserProvider);
    // Stamp data arrivals so the hero can show how fresh its figures are.
    // A silent SSE drop therefore reads as an ageing timestamp, never as
    // silently frozen numbers.
    ref.listen(accountSummaryProvider, (_, next) {
      if (next.hasValue) _stamp();
    });
    ref.listen(vaultStatusProvider, (_, next) {
      if (next.hasValue) _stamp();
    });
    final vaultAsync = ref.watch(vaultStatusProvider);
    final vaultUsdc = vaultAsync.valueOrNull == null
        ? 0.0
        : CurrencyFormatter.vaultUsdc(
            vaultAsync.valueOrNull!.vaultUsdcBalance);
    final network = vaultAsync.valueOrNull?.network ?? '';
    final networkMode = vaultAsync.valueOrNull?.mode ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                    _NetworkChip(network: network, mode: networkMode),
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
                    label: 'BALANCE',
                    amount: '₦0.00',
                    subtitle: 'Unable to load balance',
                    isHero: true,
                  ),
                ),
                data: (summary) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _BalanceSection(
                    summary: summary,
                    obscured: _obscured,
                    freshness: _freshness,
                    currency: _displayCurrency,
                    onToggleObscure: () =>
                        setState(() => _obscured = !_obscured),
                    onCurrencyChanged: (c) =>
                        setState(() => _displayCurrency = c),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Live rate reference (not a balance).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Text(
                    summaryAsync.maybeWhen(
                      data: (s) =>
                          '1 USDC = ${CurrencyFormatter.ngn(s.currentRate)}',
                      orElse: () => '',
                    ),
                    style: context.typography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Rate trend.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: RateSparklineCard(
                  rate: summaryAsync.valueOrNull?.currentRate ?? 0,
                ),
              ),
              const SizedBox(height: 24),
              // Quick Actions (right under the rate chart).
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: QuickActionsRow(),
              ),
              const SizedBox(height: 16),
              // First-run empty state: vault holds nothing yet.
              if (vaultUsdc <= 0) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _EmptyVaultCta(
                    onTopUp: () => context.push('/savings/add-money'),
                  ),
                ),
              ],
              // Pending time-locks (hidden when none).
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: PendingLockCard(),
              ),
              // Operator announcements (hidden when none).
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AnnouncementSlot(),
              ),
              // 2FA nudge (hidden once enabled).
              userAsync.maybeWhen(
                data: (u) => u.twoFactorEnabled
                    ? const SizedBox.shrink()
                    : const Padding(
                        padding:
                            EdgeInsets.only(left: 24, right: 24, top: 16),
                        child: _TwoFactorNudge(),
                      ),
                orElse: () => const SizedBox.shrink(),
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
      ),
    );
  }
}

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({
    required this.summary,
    required this.obscured,
    required this.freshness,
    required this.currency,
    required this.onToggleObscure,
    required this.onCurrencyChanged,
  });
  final AccountSummary summary;
  final bool obscured;
  final String freshness;
  final DisplayCurrency currency;
  final VoidCallback onToggleObscure;
  final ValueChanged<DisplayCurrency> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    // Your own money: the personal ledger total (available + savings),
    // credited only from confirmed on-chain deposits. Your actions move it.
    final totalNgn = summary.totalNgnEquivalent;
    final totalUsdc = summary.totalUsdtEquivalent;
    final updated =
        freshness.isEmpty ? '' : ' • updated $freshness';

    final (amount, subtitle) = switch (currency) {
      DisplayCurrency.ngn => (
          obscured ? '₦••••••' : CurrencyFormatter.ngn(totalNgn),
          obscured
              ? 'Balance hidden'
              : '≈ ${CurrencyFormatter.usdc(totalUsdc)}$updated',
        ),
      DisplayCurrency.usd => (
          obscured ? r'$••••••' : CurrencyFormatter.usdWithSymbol(totalUsdc),
          obscured
              ? 'Balance hidden'
              : '≈ ${CurrencyFormatter.ngn(totalNgn)}$updated',
        ),
      DisplayCurrency.usdc => (
          obscured ? '•••••• USDC' : CurrencyFormatter.usdc(totalUsdc),
          obscured
              ? 'Balance hidden'
              : '≈ ${CurrencyFormatter.ngn(totalNgn)}$updated',
        ),
    };

    return BalanceCard(
      label: 'BALANCE',
      amount: amount,
      subtitle: subtitle,
      isHero: true,
      trailing: IconButton(
        onPressed: onToggleObscure,
        icon: Icon(
          obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.textSecondary,
          size: 20,
        ),
        tooltip: obscured ? 'Show balance' : 'Hide balance',
        visualDensity: VisualDensity.compact,
      ),
      footer: CurrencyFlagSelector(
        current: currency,
        onChanged: onCurrencyChanged,
      ),
    );
  }
}

/// First-run empty state: shown only while the vault holds nothing.
class _EmptyVaultCta extends StatelessWidget {
  const _EmptyVaultCta({required this.onTopUp});

  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your vault is empty',
            style: context.typography.title
                .copyWith(color: AppColors.primaryForeground),
          ),
          const SizedBox(height: 6),
          Text(
            'Send USDC to your deposit address and watch it appear here.',
            style: context.typography.bodySmall
                .copyWith(color: AppColors.primaryForeground),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTopUp,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryForeground,
                side: BorderSide(color: AppColors.primaryForeground),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Top up to get started'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line nudge shown only while two-factor authentication is off.
class _TwoFactorNudge extends StatelessWidget {
  const _TwoFactorNudge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Protect your account with two-factor authentication',
              style: context.typography.bodySmall,
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/profile/security-center'),
            child: Text(
              'Enable',
              style: context.typography.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connected-network indicator (chain + test-mode marker).
class _NetworkChip extends StatelessWidget {
  const _NetworkChip({required this.network, required this.mode});

  final String network;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final label = network.isEmpty ? 'Offline' : network;
    final testMode = mode.toLowerCase() == 'mock';
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryOverlay,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        testMode ? '$label • test' : label,
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
