import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/pin_verify_sheet.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../shared/services/api_client.dart';
import '../../../../shared/services/conversion_service.dart';
import '../../../../shared/services/ethereum_provider.dart';
import '../../../../shared/services/savings_client.dart';

class WithdrawalReviewPage extends ConsumerStatefulWidget {
  const WithdrawalReviewPage({
    super.key,
    this.amount,
    this.account,
    this.destination,
    this.network,
  });

  final double? amount;
  final dynamic account; // kept for compatibility; unused in the vault flow
  final String? destination;
  final String? network;

  @override
  ConsumerState<WithdrawalReviewPage> createState() =>
      _WithdrawalReviewPageState();
}

class _WithdrawalReviewPageState extends ConsumerState<WithdrawalReviewPage> {
  bool _isProcessing = false;
  double? _usdcEstimate;
  bool _selfCustodySigned = false;
  String? _signingWallet;

  static final _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  /// Client-side mirror of the server withdrawal fee (GLOBMINT_WITHDRAW_FEE_*
  /// defaults: 20 bps = 0.2%, min ₦10, cap ₦100). Display-only: the server is
  /// authoritative and computes the same schedule in kobo.
  double _withdrawalFee(double amountNgn) {
    if (amountNgn <= 0) return 0;
    final raw = amountNgn * 20 / 10000;
    return raw.clamp(10.0, 100.0);
  }

  /// Human-friendly network name for display and confirmation: prefers the
  /// withdrawal form's choice (e.g. "Ethereum (Sepolia)"), else the deposit
  /// info's derived label.
  String _networkLabel(DepositInfo? info) {
    if (widget.network?.isNotEmpty == true) return widget.network!;
    return info?.networkLabel ?? 'on-chain';
  }

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final a = widget.amount ?? 0;
    if (a <= 0 || a < ConversionService.minQuoteAmount) return;
    try {
      final q = await ref
          .read(conversionServiceProvider)
          .getQuote(amount: a, fromCurrency: 'NGN', toCurrency: 'USDC');
      if (mounted) setState(() => _usdcEstimate = q.outputAmount);
    } catch (_) {
      // No inverse NGN->USDC rate available; omit the USDC line.
    }
  }

  Future<void> _confirmWithdrawal() async {
    final a = widget.amount ?? 0;
    final destination = widget.destination?.trim() ?? '';
    if (a <= 0 || destination.isEmpty) return;
    if (!_addressPattern.hasMatch(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Invalid destination address — it must be 0x followed by 40 hex characters.')),
      );
      return;
    }
    final fee = _withdrawalFee(a);
    final depositInfo = ref.read(depositInfoProvider).valueOrNull;

    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Finalize withdrawal?',
      details: [
        ConfirmationDetail(
            label: 'Coin',
            value: depositInfo?.assetLabel ?? 'USDC'),
        ConfirmationDetail(label: 'Network', value: _networkLabel(depositInfo)),
        ConfirmationDetail(
            label: 'Amount', value: CurrencyFormatter.ngn(a), isHighlighted: true),
        ConfirmationDetail(
            label: 'Fee (0.2%)', value: CurrencyFormatter.ngn(fee)),
        ConfirmationDetail(
            label: 'Total charged', value: CurrencyFormatter.ngn(a + fee)),
        if (_usdcEstimate != null)
          ConfirmationDetail(
              label: 'You receive',
              value: '≈ ${_usdcEstimate!.toStringAsFixed(2)} USDC'),
        ConfirmationDetail(label: 'To', value: destination),
      ],
      confirmText: 'Confirm',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final pin = await showPinVerifySheet(
        context,
        title: 'Enter your PIN',
        subtitle: 'Verify it\u2019s you before sending ${CurrencyFormatter.ngn(a)}',
        onVerify: (pin) => ref.read(authServiceProvider).verifyPin(pin),
      );
      if (pin == null || !mounted) return;

      setState(() => _isProcessing = true);
      try {
        final client = ref.read(savingsClientProvider);

        // Quote the exact EIP-712 payload: if the owner's wallet is connected,
        // sign it in the wallet so the backend only relays the owner-authorized
        // withdrawWithSig. Otherwise the transitional server-relayed path runs
        // (and is refused server-side when signature-gating is enforced).
        WithdrawSignature? outSig;
        try {
          final quote = await client.prepareWithdrawal(
            amount: a.toStringAsFixed(2),
            destination: destination,
          );
          if (EthereumProvider.available &&
              await EthereumProvider.instance.isConnectedOwner(quote.cloneOwner)) {
            final signer = (await EthereumProvider.instance.accounts()).first;
            outSig = await EthereumProvider.instance.signWithdrawal(quote, signer);
            _signingWallet = signer;
          }
        } catch (_) {
          // Quote/prepare is advisory; any failure falls back to the server path.
        }

        final result = await client.withdrawToAddress(
          amount: a.toStringAsFixed(2),
          destination: destination,
          pin: pin,
          signature: outSig,
        );

        if (mounted) {
          setState(() {
            _isProcessing = false;
            _selfCustodySigned = outSig != null;
          });
          ref.invalidate(accountSummaryProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(vaultStatusProvider);
          if (result.elevation != null) {
            _showPendingLock(a, result.elevation!);
          } else {
            _showSuccess(a, result.txHash);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          final message = e is ApiException ? e.message : '$e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Withdrawal failed: $message')),
          );
        }
      }
    }
  }

  void _showSuccess(double amount, String txHash) {
    SuccessDialog.show(
      context: context,
      type: SuccessDialogType.success,
      title: 'Withdrawal Sent',
      amount: CurrencyFormatter.ngn(amount),
      subtitle: 'USDC sent on-chain. Transaction: $txHash',
      onPressed: () => context.go('/savings'),
    );
  }

  /// An elevated amount was stored as a time-locked withdrawal: nothing left
  /// the vault yet, it broadcasts automatically after the delay.
  void _showPendingLock(double amount, PendingElevation elevation) {
    final subtitle = 'Locked for ${elevation.durationLabel}. '
        'USDC is sent automatically once released.';
    SuccessDialog.show(
      context: context,
      type: SuccessDialogType.warning,
      title: 'Withdrawal Locked',
      amount: CurrencyFormatter.ngn(amount),
      subtitle: subtitle,
      onPressed: () => context.go('/savings'),
    );
  }

  Widget _custodyBadge() {
    final connected = EthereumProvider.available;
    final owner = _signingWallet;
    if (_selfCustodySigned && owner != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.successMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Authorized by your wallet ${_shorten(owner)} — only this exact signed withdrawal can be sent.',
                style: context.typography.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    if (connected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.successMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A wallet is connected. Connect the wallet that owns your '
                'savings address to sign this withdrawal yourself.',
                style: context.typography.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  static String _shorten(String addr) {
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.amount ?? 0;
    final destination = widget.destination?.trim() ?? '';
    final fee = _withdrawalFee(a);
    final depositInfo = ref.watch(depositInfoProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Withdrawal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    Text('You withdraw', style: context.typography.labelMedium),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.ngn(a),
                        style: context.typography.amountHero),
                    if (_usdcEstimate != null) ...[
                      const SizedBox(height: 4),
                      Text('≈ ${_usdcEstimate!.toStringAsFixed(2)} USDC',
                          style: context.typography.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ReviewRow(
                label: 'Fee (0.2%, min ₦10, cap ₦100)',
                value: CurrencyFormatter.ngn(fee),
              ),
              _ReviewRow(
                label: 'Total charged',
                value: CurrencyFormatter.ngn(a + fee),
              ),
              if (_usdcEstimate != null)
                _ReviewRow(
                  label: 'You receive',
                  value: '≈ ${_usdcEstimate!.toStringAsFixed(2)} USDC',
                ),
              _ReviewRow(
                label: 'Destination',
                value: destination,
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 8),
              _ReviewRow(
                label: 'Coin',
                value: depositInfo?.assetLabel ?? 'USDC',
              ),
              _ReviewRow(
                label: 'Network',
                value: _networkLabel(depositInfo),
              ),
              if (_signingWallet != null)
                _ReviewRow(
                  label: 'Authorized by',
                  value: _shorten(_signingWallet!),
                ),
              const SizedBox(height: 16),
              _custodyBadge(),
              const SizedBox(height: 32),
              AppButton(
                text: 'Confirm Withdrawal',
                isExpanded: true,
                isLoading: _isProcessing,
                onPressed: _confirmWithdrawal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.typography.bodyMedium),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.typography.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
