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
import '../../../../shared/services/wallet_service.dart';

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
  WithdrawQuote? _quote;

  static final _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  /// Client-side mirror of the server withdrawal fee (GLOBMINT_WITHDRAW_FEE_*
  /// defaults: 20 bps = 0.2%, min ₦10, cap ₦100). Display-only: the server is
  /// authoritative and computes the same schedule in kobo.
  double _withdrawalFee(double amountNgn) {
    if (amountNgn <= 0) return 0;
    final raw = amountNgn * 20 / 10000;
    return raw.clamp(10.0, 100.0);
  }

  /// The fee shown on the review screen: the server-prepared figure when the
  /// quote loaded, else the client-side mirror.
  double get _feeNgn {
    final quote = _quote;
    if (quote != null && quote.feeNgnMinor > 0) {
      return quote.feeNgnMinor / 100;
    }
    return _withdrawalFee(widget.amount ?? 0);
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
    final client = ref.read(savingsClientProvider);
    try {
      // Prepare the exact EIP-712 payload up front so the review screen shows
      // server-authoritative NGN/fee figures and knows which wallet must sign.
      final quote = await client.prepareWithdrawal(
        amount: a.toStringAsFixed(2),
        destination: widget.destination?.trim() ?? '',
      );
      if (mounted) setState(() => _quote = quote);
    } catch (_) {
      // Prepare is advisory; the NGN->USDC line below still loads.
    }
    try {
      final q = await ref
          .read(conversionServiceProvider)
          .getQuote(amount: a, fromCurrency: 'NGN', toCurrency: 'USDC');
      if (mounted) setState(() => _usdcEstimate = q.outputAmount);
    } catch (_) {
      // No inverse NGN->USDC rate available; omit the USDC line.
    }
  }

  /// The owner seat the quote says must sign, shortened for display.
  String? get _ownerShort {
    final q = _quote;
    if (q == null || q.cloneOwner.isEmpty) return null;
    return _shorten(q.cloneOwner);
  }

  /// The expected chain for signing: the quote's domain, else the deposit info.
  int get _chainId {
    final quote = _quote;
    if (quote != null && quote.domain.chainId != 0) return quote.domain.chainId;
    final depositInfo = ref.read(depositInfoProvider).valueOrNull;
    return depositInfo?.chainId ?? 0;
  }

  /// Signs the [WithdrawQuote] when the connected wallet is the clone owner.
  /// Returns null when the wallet isn't connected or isn't the owner (the
  /// caller then falls back to the PIN path or the custody walkthrough).
  Future<WithdrawSignature?> _signQuoteIfOwner(WithdrawQuote? quote) async {
    if (quote == null) return null;
    final wallet = ref.read(walletProvider);
    if (!wallet.isConnected || wallet.address == null) return null;
    final owner = quote.cloneOwner.toLowerCase();
    if (owner.isNotEmpty && wallet.address!.toLowerCase() != owner) return null;

    final typedData = EthereumProvider.instance.typedDataV4For(quote);
    final signature = await ref.read(walletProvider.notifier).signTypedData(typedData);
    final m = quote.message;
    return WithdrawSignature(
      signature: signature,
      deadline: m.deadline,
      nonce: m.nonce,
      amountMinorBase: BigInt.parse(m.amount).toInt(),
    );
  }

  /// Connects the owner wallet, pinning to the expected chain. Prompts to
  /// switch when the connected wallet is on the wrong network. Returns true
  /// when a wallet is connected afterwards.
  Future<bool> _connectOwnerFor(WithdrawQuote? quote) async {
    final notifier = ref.read(walletProvider.notifier);
    final expected = _chainId;
    if (!ref.read(walletProvider).hasWallet) {
      _toast('No wallet detected. Use a browser with MetaMask installed '
          'to sign this withdrawal yourself.');
      return false;
    }
    if (!ref.read(walletProvider).isConnected) {
      try {
        await notifier.connect(expectedChainId: expected);
      } on WalletWrongChainException {
        if (!await _offerChainSwitch(expected)) return false;
      }
    }
    if (ref.read(walletProvider).status == WalletConnectionStatus.wrongChain) {
      if (!await _offerChainSwitch(expected)) return false;
    }
    final wallet = ref.read(walletProvider);
    if (!wallet.isConnected || wallet.address == null) return false;
    return true;
  }

  /// Asks the wallet to switch to [expected]; returns true when the wallet is
  /// then on the right chain.
  Future<bool> _offerChainSwitch(int expected) async {
    if (expected == 0) return false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch network?'),
        content: Text(
          'Your wallet is on a different network. Switch it to chain '
          '$expected so this withdrawal can be signed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return false;
    try {
      await ref.read(walletProvider.notifier).ensureChain(expected);
      return ref.read(walletProvider).isConnected;
    } on WalletWrongChainException catch (e) {
      _toast('Could not switch networks: ${e.toString()}');
      return false;
    }
  }

  /// Explains why the withdrawal needs a wallet signature (SIGNATURE_REQUIRED
  /// / custody still held by the platform signer) and points to the Vault
  /// Recovery page.
  Future<void> _showSignatureRequired() async {
    final wallet = ref.read(walletProvider);
    final owner = _ownerShort;
    final connectedGood = wallet.isConnected &&
        owner != null &&
        wallet.address?.toLowerCase() == _quote!.cloneOwner.toLowerCase();
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wallet signature required'),
        content: Text(
          connectedGood
              ? 'This withdrawal must be authorized in your wallet. Tap '
                  'Sign & Withdraw again and approve the request when your '
                  'wallet opens.'
              : owner != null
                  ? 'Only the wallet that owns your savings address '
                      '($owner) can authorize this withdrawal. Connect that '
                      'wallet and try again.\n\nIf that wallet belongs to a '
                      'device you no longer have, use Vault Recovery to '
                      'designate a backup address.'
                  : 'This withdrawal must be authorized by the wallet that '
                      'owns your savings address. Connect that wallet and '
                      'try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWithdrawal() async {
    final a = widget.amount ?? 0;
    final destination = widget.destination?.trim() ?? '';
    if (a <= 0 || destination.isEmpty) return;
    if (!_addressPattern.hasMatch(destination)) {
      _toast(
          'Invalid destination address — it must be 0x followed by 40 hex characters.');
      return;
    }
    final fee = _feeNgn;
    final depositInfo = ref.read(depositInfoProvider).valueOrNull;
    // The PIN (platform-relayed) path is only offered when the backend
    // advertises transitional mode. Signature-gated mode requires a wallet.
    final requiresSignature = depositInfo?.requireUserSignature ?? false;

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

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    String pin = '';
    WithdrawSignature? outSig;
    try {
      final client = ref.read(savingsClientProvider);

      if (requiresSignature) {
        if (!await _connectOwnerFor(_quote)) return;
        outSig = await _signQuoteIfOwner(_quote);
        if (outSig == null) {
          // Connected wallet isn't the owner (or the owner is still the
          // platform signer): the backend would refuse with SIGNATURE_REQUIRED.
          await _showSignatureRequired();
          return;
        }
      } else {
        // Transitional mode (backend advertises require_user_signature=false):
        // prefer a connected owner's signature, else fall back to the PIN path.
        outSig = await _signQuoteIfOwner(_quote);
        if (outSig == null) {
          if (!mounted) return;
          pin = await showPinVerifySheet(
                context,
                title: 'Enter your PIN',
                subtitle:
                    'Verify it\u2019s you before sending ${CurrencyFormatter.ngn(a)}',
                onVerify: (value) =>
                    ref.read(authServiceProvider).verifyPin(value),
              ) ??
              '';
          if (pin.isEmpty || !mounted) return;
        }
      }

      final result = await client.withdrawToAddress(
        amount: a.toStringAsFixed(2),
        destination: destination,
        pin: pin,
        signature: outSig,
      );

      if (!mounted) return;
      if (outSig != null && outSig.signature.isNotEmpty) {
        _signingWallet = ref.read(walletProvider).address;
        _selfCustodySigned = true;
      }
      ref.invalidate(accountSummaryProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(vaultStatusProvider);
      if (result.elevation != null) {
        _showPendingLock(a, result.elevation!);
      } else {
        _showSuccess(a, result.txHash);
      }
    } on ApiException catch (e) {
      if (e.code == 'SIGNATURE_REQUIRED') {
        await _showSignatureRequired();
      } else {
        _toast('Withdrawal failed: ${e.message}');
      }
    } on WalletWrongChainException {
      await _offerChainSwitch(_chainId);
    } on WalletSignatureException catch (e) {
      _toast('Withdrawal not signed: ${e.message}. Tap again to retry.');
    } on WalletConnectionException catch (e) {
      _toast(e.message);
    } on WalletUnavailableException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Withdrawal failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final wallet = ref.watch(walletProvider);
    final requiresSignature =
        ref.read(depositInfoProvider).valueOrNull?.requireUserSignature ?? false;
    final owner = _ownerShort;

    if (_selfCustodySigned && _signingWallet != null) {
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
                'Authorized by your wallet ${_shorten(_signingWallet!)} — only this exact signed withdrawal can be sent.',
                style: context.typography.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    if (wallet.isConnected && owner != null && wallet.address?.toLowerCase() == _quote!.cloneOwner.toLowerCase()) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.successMuted.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connected as owner — you\u2019ll sign this withdrawal in your wallet.',
                style: context.typography.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    if (requiresSignature) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warningMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                wallet.isConnected
                    ? (owner != null
                        ? 'Connect ${_shorten(owner)} in your wallet to authorize this withdrawal.'
                        : 'Connect the wallet that owns your savings address to authorize this withdrawal.')
                    : 'This withdrawal must be signed by the wallet that owns your savings address.',
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
    final fee = _feeNgn;
    final depositInfo = ref.watch(depositInfoProvider).valueOrNull;
    final requiresSignature = depositInfo?.requireUserSignature ?? false;
    final wallet = ref.watch(walletProvider);

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
                text: requiresSignature || wallet.isConnected
                    ? 'Connect & Sign Withdraw'
                    : 'Confirm Withdrawal',
                isExpanded: true,
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _confirmWithdrawal,
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