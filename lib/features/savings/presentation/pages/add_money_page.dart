import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/savings_client.dart';

/// Personal savings vault. You top it up by sending USDC on-chain to the
/// deposit address shown here. The app watches that address and auto-credits
/// your NGN balance when funds arrive — you never type an amount.
class AddMoneyPage extends ConsumerStatefulWidget {
  const AddMoneyPage({super.key});

  @override
  ConsumerState<AddMoneyPage> createState() => _AddMoneyPageState();
}

class _AddMoneyPageState extends ConsumerState<AddMoneyPage> {
  final _addressController = TextEditingController();
  DepositInfo? _deposit;
  bool _depositError = false;
  bool _linking = false;
  bool _copied = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadDeposit();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      ref.invalidate(accountSummaryProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadDeposit() async {
    try {
      final info = await ref.read(savingsClientProvider).getDepositInfo();
      if (mounted) {
        setState(() {
          _deposit = info;
          _depositError = false;
          _addressController.text =
              info.address.isEmpty || info.address == DepositInfo.zeroAddress
                  ? ''
                  : info.address;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _depositError = true);
    }
  }

  Future<void> _linkAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your wallet address')),
      );
      return;
    }
    setState(() => _linking = true);
    try {
      await ref.read(savingsClientProvider).setDepositAddress(address);
      if (mounted) {
        setState(() => _linking = false);
        ref.invalidate(depositInfoProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet linked successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _linking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not link wallet: $e')),
        );
      }
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
                      'Funds arriving here are detected and added to your NGN balance automatically. No amount needed.',
                      style: context.typography.bodySmall,
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
              // Link your source wallet so deposits are credited to you.
              Text('Link your wallet', style: context.typography.title),
              const SizedBox(height: 6),
              Text(
                'Deposits sent to your vault are credited to the linked wallet below. Keep it set to your own address.',
                style: context.typography.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                enabled: !_linking,
                style: context.typography.bodyMedium,
                decoration: InputDecoration(
                  hintText: '0x…',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Save linked wallet',
                onPressed: _linkAddress,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                isLoading: _linking,
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Using the local hardhat network — test USDC only',
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
