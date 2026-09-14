import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/services/wallet_service.dart';

/// A wallet connect/disconnect control driven by [walletProvider]. Renders the
/// right affordance for the current state:
///
///  * disconnected + wallet available → "Connect wallet" (pins to
///    [expectedChainId] when supplied and offers to switch when the wallet is
///    on another network);
///  * connecting / signing          → a disabled busy state;
///  * connected                      → "Disconnect";
///  * wrong network                  → "Switch network".
///
/// All failures are reflected in `walletProvider.error` for surrounding cards
/// to surface; the button itself never hides the cause.
class WalletConnectButton extends ConsumerStatefulWidget {
  const WalletConnectButton({super.key, this.expectedChainId});

  /// The chain signing must happen on (e.g. the deposit info's `chain_id`).
  /// When non-zero the button connects pinned to it and offers to switch.
  final int? expectedChainId;

  @override
  ConsumerState<WalletConnectButton> createState() =>
      _WalletConnectButtonState();
}

class _WalletConnectButtonState extends ConsumerState<WalletConnectButton> {
  Future<void> _connect() async {
    final notifier = ref.read(walletProvider.notifier);
    final expected = widget.expectedChainId ?? 0;
    try {
      await notifier.connect(expectedChainId: expected == 0 ? null : expected);
    } on WalletWrongChainException {
      await _offerChainSwitch(expected);
    } catch (_) {
      // Failure reason is surfaced in walletProvider.error for the card.
    }
  }

  Future<void> _offerChainSwitch(int expected) async {
    if (expected == 0 || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch network?'),
        content: Text(
          'Switch your wallet to chain $expected so it can sign '
          'withdrawals?',
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
    if (ok != true || !mounted) return;
    try {
      await ref.read(walletProvider.notifier).ensureChain(expected);
    } on WalletWrongChainException {
      // Card reflects the wrongChain state; nothing else to do.
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final chain = wallet.chainId ?? 0;

    if (wallet.isBusy) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(wallet.signing ? 'Signing…' : 'Connecting…'),
      );
    }
    if (wallet.status == WalletConnectionStatus.wrongChain && chain != 0) {
      return OutlinedButton.icon(
        onPressed: () => _offerChainSwitch(widget.expectedChainId ?? 0),
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: const Text('Switch network'),
      );
    }
    if (wallet.isConnected) {
      return TextButton.icon(
        onPressed: () => ref.read(walletProvider.notifier).disconnect(),
        icon: const Icon(Icons.link_off, size: 18),
        label: const Text('Disconnect'),
      );
    }
    if (wallet.hasWallet) {
      return OutlinedButton.icon(
        onPressed: _connect,
        icon: const Icon(Icons.link, size: 18),
        label: const Text('Connect wallet'),
      );
    }
    return const SizedBox.shrink();
  }
}