import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/success_dialog.dart';
import '../../../../shared/services/api_client.dart';
import '../../../../shared/services/ethereum_provider.dart';
import '../../../../shared/services/savings_client.dart';
import '../../../../shared/services/wallet_service.dart';
import '../widgets/wallet_connect_pairing_dialog.dart';

/// Vault recovery & security settings: shows the clone's designated recovery
/// address, delay, and any in-flight recovery window, and lets the user
/// designate (or re-designate) a recovery address that can take over the vault
/// if the wallet key to the owner seat is lost.
class VaultRecoveryPage extends ConsumerStatefulWidget {
  const VaultRecoveryPage({super.key});

  @override
  ConsumerState<VaultRecoveryPage> createState() => _VaultRecoveryPageState();
}

class _VaultRecoveryPageState extends ConsumerState<VaultRecoveryPage> {
  static final _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  final _controller = TextEditingController();
  bool _isSubmitting = false;

  static final _zeroAddress =
      '0x0000000000000000000000000000000000000000';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _designate() async {
    final raw = _controller.text.trim();
    if (!_addressPattern.hasMatch(raw)) {
      _toast('Enter a valid Ethereum address (0x + 40 hex characters)');
      return;
    }
    if (raw.toLowerCase() == _zeroAddress) {
      _toast('The zero address cannot be a recovery address');
      return;
    }
    final client = ref.read(savingsClientProvider);
    setState(() => _isSubmitting = true);
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final quote = await client.prepareRecovery(raw);
        final signature = await _authorizeAndSign(quote);
        if (signature == null) return;

        final RecoverySignatureResult result;
        try {
          result = await client.setRecoveryAddress(
            recoveryAddress: raw,
            signature: signature,
          );
        } on ApiException catch (e) {
          if (e.message.toLowerCase().contains('signature_expired')) {
            // The deadline lapsed (or the clone nonce changed): pull a fresh
            // quote and reauthorize instead of failing the whole flow.
            _toast('That signature expired — please reauthorize.');
            continue;
          }
          if (mounted) _toast(_friendly(e.message));
          return;
        }

        if (!mounted) return;
        ref.invalidate(vaultRecoveryProvider);
        await _showSuccess(raw, result.txHash);
        if (mounted) _controller.clear();
        return;
      }
      if (mounted) _toast('Still not set — please try again in a moment.');
    } on ApiException catch (e) {
      if (mounted) _toast(_friendly(e.message));
    } catch (e) {
      if (mounted) _toast('Could not designate recovery address: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Connects the owner wallet for [quote] — choosing the backend when several
  /// are available and showing the WalletConnect QR/deep-link flow when that
  /// backend needs pairing — verifies the owner seat, then signs the EIP-712
  /// quote. Returns the client-shaped signature, or null when the user
  /// cancelled or the flow failed (a message is displayed).
  Future<RecoverySignature?> _authorizeAndSign(RecoveryQuote quote) async {
    final expected = quote.domain.chainId;
    final notifier = ref.read(walletProvider.notifier);
    if (!ref.read(walletProvider).hasWallet) {
      _toast('No wallet is available here. Use a browser with MetaMask '
          'installed, or the WalletConnect flow on your phone.');
      return null;
    }

    final owner = quote.cloneOwner.toLowerCase();

    // Already signed in as the owner on the expected chain: skip connect.
    final wallet = ref.read(walletProvider);
    if (wallet.isConnected &&
        wallet.address != null &&
        (owner.isEmpty || wallet.address!.toLowerCase() == owner) &&
        (expected == 0 ||
            wallet.chainId == null ||
            wallet.chainId == 0 ||
            wallet.chainId == expected)) {
      return _sign(quote);
    }

    WalletBackend? backend;
    final available = notifier.availableBackends;
    if (available.length > 1) {
      backend = await _chooseBackend(available);
      if (backend == null) return null;
    }
    backend = backend ?? notifier.defaultBackend;

    final bool connected;
    if (backend is WalletPairingProvider) {
      connected =
          await _connectWithPairing(backend as WalletPairingProvider, expected);
    } else {
      connected = await _connectPlain(backend, expected);
    }
    if (!connected) return null;

    final after = ref.read(walletProvider);
    if (!after.isConnected || after.address == null) return null;
    if (owner.isNotEmpty && after.address!.toLowerCase() != owner) {
      _toast('Connect the wallet that owns your savings address '
          '(${_shorten(quote.cloneOwner)}) to authorize recovery.');
      return null;
    }
    return _sign(quote);
  }

  /// Plain connect (injected browser wallet or a backend with no pairing UI),
  /// with wrong-chain switching offered when needed. Returns whether a wallet
  /// is connected afterwards.
  Future<bool> _connectPlain(WalletBackend? backend, int expected) async {
    try {
      await ref
          .read(walletProvider.notifier)
          .connect(expectedChainId: expected, backend: backend);
    } on WalletConnectionException catch (e) {
      _toast(e.code == 'USER_REJECTED'
          ? 'You cancelled the connection request.'
          : e.message);
      return false;
    } on WalletWrongChainException {
      if (!await _offerChainSwitch(expected)) return false;
    } on WalletUnavailableException catch (e) {
      _toast(e.message);
      return false;
    } on ApiException catch (e) {
      _toast(e.message);
      return false;
    }
    return ref.read(walletProvider).isConnected;
  }

  /// Connects a backend that pairs in-band (WalletConnect): the QR / deep-link
  /// dialog runs while the connect call waits for the wallet-side approval.
  /// Cancelling the dialog abandons the pending pairing session. Returns
  /// whether a wallet is connected afterwards.
  Future<bool> _connectWithPairing(
      WalletPairingProvider backend, int expected) async {
    final connectWork = () async {
      try {
        await ref
            .read(walletProvider.notifier)
            .connect(expectedChainId: expected, backend: backend as WalletBackend);
        return null;
      } on WalletWrongChainException catch (e) {
        return e;
      } on WalletConnectionException catch (e) {
        return e;
      } on WalletUnavailableException catch (e) {
        return e;
      } on ApiException catch (e) {
        return e;
      }
    }();

    final dialogFuture = WalletConnectPairingDialog.show(
      context,
      pairingUris: backend.pairingUris,
      onOpenWallet: backend.launchPairingUri,
    );

    final first = await Future.any<Object?>([dialogFuture, connectWork]);
    // The dialog route may not be installed yet when [connectWork] resolved
    // on its very first microtask (e.g. an instant wallet rejection); wait a
    // frame so the route has a scope before popping it.
    if (mounted) await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).maybePop();
    if (first == false) {
      if (backend is WalletSessionEventsSource) {
        unawaited(
            (backend as WalletSessionEventsSource).disconnectSession());
      }
      return false;
    }
    if (first is WalletWrongChainException) {
      return _offerChainSwitch(expected);
    }
    if (first is WalletConnectionException) {
      _toast(first.code == 'USER_REJECTED'
          ? 'You cancelled the connection request.'
          : first.message);
      return false;
    }
    if (first is WalletUnavailableException) {
      _toast(first.message);
      return false;
    }
    if (first is ApiException) {
      _toast(first.message);
      return false;
    }
    if (first != null) {
      _toast('Could not connect the wallet: $first');
      return false;
    }
    return ref.read(walletProvider).isConnected;
  }

  /// Lets the user pick between [backends] (e.g. injected wallet vs
  /// WalletConnect). Returns null when dismissed without choosing.
  Future<WalletBackend?> _chooseBackend(List<WalletBackend> backends) async {
    return showModalBottomSheet<WalletBackend>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Connect a wallet',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...backends.map((b) => ListTile(
                  leading: Icon(
                    b.name == 'WalletConnect'
                        ? Icons.qr_code_scanner_rounded
                        : Icons.account_balance_wallet_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(b.name),
                  subtitle: Text(b.name == 'WalletConnect'
                      ? 'Sign from your wallet app on another device'
                      : 'Sign with the wallet in this browser'),
                  onTap: () => Navigator.of(ctx).pop(b),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Asks the wallet to switch to [expected]; returns true when it is then on
  /// the right chain.
  Future<bool> _offerChainSwitch(int expected) async {
    if (expected == 0) return false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch network?'),
        content: Text(
          'Your wallet is on a different network. Switch it to chain '
          '$expected so recovery can be signed?',
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
    } on WalletConnectionException catch (e) {
      _toast(e.message);
      return false;
    } on WalletWrongChainException catch (e) {
      _toast('Could not switch networks: ${e.toString()}');
      return false;
    } on WalletUnavailableException catch (e) {
      _toast(e.message);
      return false;
    } on ApiException catch (e) {
      _toast(e.message);
      return false;
    }
  }

  /// Signs the recovery quote over [EthereumProvider]'s exact EIP-712 payload
  /// for it. Handles wallet-side rejection, expired sessions (offered a
  /// reconnect that re-runs [._authorizeAndSign]), and wrong-chain switches.
  Future<RecoverySignature?> _sign(RecoveryQuote quote) async {
    final typedData = EthereumProvider.instance.typedDataV4ForRecovery(quote);
    try {
      final signature =
          await ref.read(walletProvider.notifier).signTypedData(typedData);
      return RecoverySignature(
        signature: signature,
        deadline: quote.message.deadline,
        nonce: quote.message.nonce,
      );
    } on WalletSignatureException {
      _toast('You cancelled the signing request in your wallet.');
      return null;
    } on WalletConnectionException catch (e) {
      if (e.code == 'SESSION_EXPIRED') {
        if (!mounted) return null;
        final reconnect = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Session expired'),
            content: const Text(
                'Your wallet session ended while signing. Reconnect to retry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reconnect'),
              ),
            ],
          ),
        );
        if (reconnect == true && mounted) return _authorizeAndSign(quote);
        return null;
      }
      _toast(e.message);
      return null;
    } on WalletWrongChainException {
      if (await _offerChainSwitch(quote.domain.chainId)) {
        return _authorizeAndSign(quote);
      }
      return null;
    } on WalletUnavailableException catch (e) {
      _toast(e.message);
      return null;
    } on ApiException catch (e) {
      _toast(_friendly(e.message));
      return null;
    }
  }

  String _friendly(String message) {
    final m = message.toLowerCase();
    if (m.contains('signature_expired')) {
      return 'That signature expired — please try again.';
    }
    if (m.contains('signature_required')) {
      return 'Only the wallet that owns your savings address can design a recovery address.';
    }
    if (m.contains('invalid_address')) {
      return 'That address is invalid as a recovery address (zero, or already the owner).';
    }
    if (m.contains('invalid_signature')) {
      return 'That signature is invalid — sign with the wallet that owns your savings address.';
    }
    return message;
  }

  Future<void> _showSuccess(String recovery, String txHash) {
    return SuccessDialog.show(
      context: context,
      type: SuccessDialogType.success,
      title: 'Recovery Address Set',
      amount: _shorten(recovery),
      subtitle: 'You can now recover your vault from this address if your '
          'main wallet key is lost.\n\nTransaction: $_shorten(txHash)',
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _shorten(String addr) {
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }

  static String _formatEpoch(int unixSeconds) {
    if (unixSeconds <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}-${two(dt.month)}-${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(vaultRecoveryProvider);
    final status = statusAsync.valueOrNull;
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vault Recovery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recovery address', style: context.typography.title),
              const SizedBox(height: 6),
              Text(
                'If you lose the key to your owner wallet, a designated '
                'recovery address can take over this vault after a time-lock. '
                'Designate one only on a wallet you trust and control.',
                style: context.typography.bodySmall,
              ),
              const SizedBox(height: 20),
              if (statusAsync.isLoading && status == null)
                const _StatusSkeleton()
              else if (statusAsync.hasError && status == null)
                _errorCard(statusAsync.error)
              else if (status != null)
                _statusCard(status)
              else
                _errorCard(null),
              if (status != null) ...[
                const SizedBox(height: 8),
                Text(
                  'The recovery time-lock is a GlobMint platform policy set '
                  'across all vaults — you choose which address recovers it, '
                  'but not how long recovery waits.',
                  style: context.typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Designate a recovery address', style: context.typography.title),
              const SizedBox(height: 6),
              Text(
                'The wallet that owns your savings address signs the change; '
                'GlobMint only relays it.',
                style: context.typography.bodySmall,
              ),
              if (status != null && status.owner.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Owner wallet: ${status.ownerShort}',
                  style: context.typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: 'Recovery address',
                hint: '0x…',
                controller: _controller,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              if (!wallet.hasWallet) ...[
                const SizedBox(height: 12),
                _warningCard(
                  'No wallet is available in this browser. Connect via a '
                  'browser wallet extension (e.g. MetaMask) or use the '
                  'WalletConnect flow on your phone to sign the recovery '
                  'designation.',
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                text: 'Sign & Set Recovery Address',
                isExpanded: true,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _designate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(Object? error) {
    final message = error is ApiException ? error.message : 'Could not load recovery status.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Text(
        message,
        style: context.typography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _warningCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.typography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(RecoveryStatus status) {
    final hasRecovery = status.recoveryAddress.isNotEmpty &&
        status.recoveryAddress.toLowerCase() != _zeroAddress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusRow(
            'Status',
            status.recoveryPending
                ? 'Recovery in progress'
                : hasRecovery
                    ? 'Protected'
                    : 'No recovery address',
            status.recoveryPending
                ? AppColors.warning
                : hasRecovery
                    ? AppColors.success
                    : AppColors.textSecondary,
          ),
          const Divider(color: AppColors.divider, height: 1),
          _statusRow('Clone', status.cloneShort),
          _statusRow('Owner', status.ownerShort),
          _statusRow(
            'Recovery address',
            hasRecovery ? status.recoveryShort : 'Not set',
          ),
          _statusRow('Recovery delay', status.delayLabel),
          if (status.recoveryPending) ...[
            _statusRow(
              'Requested',
              _formatEpoch(status.recoveryRequestedAt),
            ),
            _statusRow('Can recover at', _formatEpoch(status.recoveryAt)),
          ],
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.typography.bodyMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.typography.labelLarge.copyWith(
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSkeleton extends StatelessWidget {
  const _StatusSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}