import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../shared/services/api_client.dart';
import '../../../../shared/services/savings_client.dart';
import '../../../profile/presentation/widgets/wallet_connect_button.dart';

/// Bottom sheet that walks a user through taking custody of their savings
/// address: ownership currently sits with the platform placeholder signer, so
/// the platform signer (the only key the clone contract accepts as CURRENT
/// owner) authorizes a `transferOwnershipBySig` handing the owner seat to the
/// user's connected wallet.
class CustodyClaimSheet extends ConsumerStatefulWidget {
  const CustodyClaimSheet({super.key, required this.custody});

  final CustodyStatus custody;

  /// Presents the sheet over [context].
  static Future<CustodyClaimResult?> show(BuildContext context, CustodyStatus custody) {
    return AppBottomSheet.show<CustodyClaimResult>(
      context: context,
      title: 'Take custody of your savings address',
      child: CustodyClaimSheet(custody: custody),
    );
  }

  @override
  ConsumerState<CustodyClaimSheet> createState() => _CustodyClaimSheetState();
}

class _CustodyClaimSheetState extends ConsumerState<CustodyClaimSheet> {
  bool _busy = false;
  CustodyQuote? _quote;
  String? _error;
  String? _txHash;

  bool get _connected => ref.watch(walletProvider).isConnected;
  String? get _newOwner =>
      _connected ? ref.watch(walletProvider).address : null;

  Future<void> _claim() async {
    final newOwner = _newOwner;
    if (newOwner == null || newOwner.isEmpty) {
      setState(() => _error = 'Connect your wallet first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = ref.read(savingsClientProvider);
    try {
      // Quote the exact TransferOwnership message the CURRENT owner (the
      // platform signer, while the clone is unclaimed) will authorize.
      final quote = await client.prepareCustody(newOwner);
      if (mounted) setState(() => _quote = quote);

      final result = await client.claimCustody(newOwner);
      if (!mounted) return;
      if (result.claimed) {
        setState(() => _txHash = result.txHash);
      } else {
        setState(() => _error = 'The claim was not acknowledged. Try again.');
        return;
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'CONFLICT' || e.statusCode == 409) {
        // Already claimed — an idempotent replay of a completed claim.
        final result = CustodyClaimResult(
          claimed: true,
          newOwner: newOwner,
          txHash: '',
        );
        _complete(result);
        return;
      }
      setState(() => _error = e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
      return;
    }

    final result = CustodyClaimResult(
      claimed: true,
      newOwner: newOwner,
      txHash: _txHash ?? '',
    );
    _complete(result);
  }

  void _complete(CustodyClaimResult result) {
    ref.invalidate(custodyProvider);
    ref.invalidate(depositInfoProvider);
    if (!mounted) return;
    Navigator.of(context).pop(result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.txHash.isNotEmpty
              ? 'Custody claimed — transaction ${_shorten(result.txHash)}'
              : 'Your savings address is now owned by your wallet.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custody = widget.custody;
    final wallet = ref.watch(walletProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current owner', style: context.typography.labelMedium),
                const SizedBox(height: 4),
                Text(
                  custody.placeholderShort.isEmpty
                      ? _shorten(custody.owner)
                      : '${_shorten(custody.owner)} (platform placeholder)',
                  style: context.typography.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Until you claim it, the platform signer owns this address and '
                  'authorizes every signed withdrawal. Taking custody hands the '
                  'owner seat to your wallet — only your wallet can then sign.',
                  style: context.typography.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (custody.clone.isNotEmpty) ...[
            _row('Savings address', _shorten(custody.clone)),
            const SizedBox(height: 8),
            _row('Current nonce', '${custody.nonce}'),
          ],
          if (_quote != null) ...[
            const SizedBox(height: 20),
            Text(
              'Exact message the platform signer authorizes',
              style: context.typography.labelMedium,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Transfer ownership to', _shorten(_quote!.message.newOwner)),
                  const SizedBox(height: 8),
                  _row('Nonce', '${_quote!.message.nonce}'),
                  const SizedBox(height: 8),
                  _row('Deadline (Unix)', '${_quote!.message.deadline}'),
                  const SizedBox(height: 8),
                  _row('Verifying contract', _shorten(_quote!.domain.verifyingContract)),
                  const SizedBox(height: 12),
                  Text(
                    'This is the EIP-712 payload — the only message the clone '
                    'contract accepts from its current owner.',
                    style: context.typography.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (!wallet.hasWallet) ...[
            Text(
              'No wallet detected. Install MetaMask in this browser to claim '
              'custody for your wallet.',
              style: context.typography.bodySmall.copyWith(
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 16),
          ] else if (!_connected) ...[
            Text(
              'Connect the wallet that will own your savings address.',
              style: context.typography.bodySmall,
            ),
            const SizedBox(height: 16),
          ],
          WalletConnectButton(
            expectedChainId:
                ref.read(depositInfoProvider).valueOrNull?.chainId,
          ),
          if (_connected && _newOwner != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Custody will be handed to your wallet '
                '${_shorten(_newOwner!)}. This cannot be undone — only your '
                'wallet can sign withdrawals for this address afterwards.',
                style: context.typography.bodySmall,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: context.typography.bodySmall.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            text: _connected ? 'Claim custody with my wallet' : 'Claim custody',
            isExpanded: true,
            isLoading: _busy,
            isEnabled: _connected && !_busy,
            onPressed: _claim,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.typography.bodySmall),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: context.typography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  static String _shorten(String addr) {
    if (addr.isEmpty) return '—';
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }
}