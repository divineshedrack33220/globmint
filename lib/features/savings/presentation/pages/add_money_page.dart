import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/savings_client.dart';
import '../../../../shared/widgets/stablecoin_risk_disclosure.dart';

/// Personal savings vault. You top it up by sending USDC on-chain to the
/// deposit address shown here. The app watches that address and reflects every
/// incoming deposit as vault holdings (valued in NGN at the live rate) and in
/// your transaction history — no wallet linking required.
class AddMoneyPage extends ConsumerStatefulWidget {
  const AddMoneyPage({super.key});

  @override
  ConsumerState<AddMoneyPage> createState() => _AddMoneyPageState();
}

class _AddMoneyPageState extends ConsumerState<AddMoneyPage> {
  DepositInfo? _deposit;
  bool _depositError = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadDeposit();
  }

  Future<void> _loadDeposit() async {
    try {
      final info = await ref.read(savingsClientProvider).getDepositInfo();
      if (mounted) {
        setState(() {
          _deposit = info;
          _depositError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _depositError = true);
    }
  }

  void _copyAddress() {
    final addr = _deposit?.address ?? '';
    if (addr.isEmpty) return;
    Clipboard.setData(ClipboardData(text: addr));
    setState(() => _copied = true);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final availableBalance = summaryAsync.valueOrNull?.available.balance ?? 0;

    final deposit = _deposit;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Top up your vault')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Available balance (auto-refreshes as deposits arrive).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available Balance', style: context.typography.bodyMedium),
                    Text(
                      CurrencyFormatter.ngn(availableBalance),
                      style: context.typography.amountMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _VaultHoldingsCard(),
              const SizedBox(height: 24),
              const StablecoinRiskDisclosure(),
              const SizedBox(height: 24),
              // Deposit address card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Send USDC to your vault',
                              style: context.typography.title),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Send any amount of USDC from any wallet. The app '
                      'watches this address on-chain and reflects deposits '
                      'automatically — no sender link required.',
                      style: context.typography.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.visibility_outlined,
                            color: AppColors.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Watch-only address: the app observes this address '
                            'to credit you, but cannot spend from it — funds '
                            'are held by the vault smart contract under its '
                            'own key.',
                            style: context.typography.bodySmall.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (deposit == null && _depositError)
                      Text('Deposit details are unavailable right now.',
                          style: context.typography.bodySmall)
                    else if (deposit == null)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary)))
                    else ...[
                      _label(context, 'Deposit address'),
                      const SizedBox(height: 6),
                      _addressBox(context, deposit.address, onCopy: _copyAddress),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _chip(context, 'Network', deposit.network),
                          _chip(context, 'Chain', '${deposit.chainId}'),
                          _chip(
                            context,
                            'Asset',
                            '${deposit.stablecoinSymbol} · ${deposit.stablecoinName}',
                          ),
                        ],
                      ),
                      if (deposit.vaultContract.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _label(context, 'Vault contract'),
                        const SizedBox(height: 6),
                        SelectableText(
                          deposit.vaultContract,
                          style: context.typography.bodySmall.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  deposit?.network != null && deposit!.network.isNotEmpty
                      ? 'Live on ${deposit.network} — USDC (${deposit.stablecoinSymbol})'
                      : 'Sending to the vault is detected automatically',
                  textAlign: TextAlign.center,
                  style: context.typography.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) =>
      Text(text, style: context.typography.bodySmall);

  Widget _chip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: context.typography.bodySmall),
          const SizedBox(width: 4),
          Text(value, style: context.typography.labelLarge),
        ],
      ),
    );
  }

  Widget _addressBox(BuildContext context, String address,
      {VoidCallback? onCopy}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(address, style: context.typography.labelLarge),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCopy,
            icon: Icon(
              _copied ? Icons.check : Icons.copy,
              color: AppColors.primary,
              size: 18,
            ),
            tooltip: _copied ? 'Copied' : 'Copy address',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Live vault holdings: the on-chain USDC balance converted to NGN at the
/// current rate, so the account holder always sees what their vault is worth.
class _VaultHoldingsCard extends ConsumerWidget {
  const _VaultHoldingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultStatusProvider).valueOrNull;
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final rate = summary?.currentRate ?? 0;
    final usdc = vault == null ? 0.0 : CurrencyFormatter.vaultUsdc(vault.vaultUsdcBalance);
    final vaultNgn = usdc * rate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline,
                  color: AppColors.primaryForeground, size: 20),
              const SizedBox(width: 8),
              Text(
                'YOUR VAULT',
                style: context.typography.labelMedium
                    .copyWith(color: AppColors.primaryForeground),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _fmtUsdc(usdc),
            style: context.typography.headline
                .copyWith(color: AppColors.primaryForeground),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ ${CurrencyFormatter.ngn(vaultNgn)}',
            style: context.typography.amountMedium
                .copyWith(color: AppColors.primaryForeground),
          ),
          const SizedBox(height: 10),
          Text(
            '1 USDC = ${CurrencyFormatter.ngn(rate)}',
            style: context.typography.bodySmall
                .copyWith(color: AppColors.primaryForeground),
          ),
        ],
      ),
    );
  }

  String _fmtUsdc(double v) =>
      '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)} USDC';
}
