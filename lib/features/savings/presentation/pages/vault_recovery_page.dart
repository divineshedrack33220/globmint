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
      final quote = await client.prepareRecovery(raw);

      if (!EthereumProvider.available ||
          !await EthereumProvider.instance.isConnectedOwner(quote.cloneOwner)) {
        _toast('Connect the wallet that owns your savings address '
            '(${quote.cloneOwner.isEmpty ? 'no owner' : _shorten(quote.cloneOwner)}) '
            'to authorize recovery.');
        return;
      }
      final signer = (await EthereumProvider.instance.accounts()).first;
      final sig = await EthereumProvider.instance.signRecovery(quote, signer);
      final result = await client.setRecoveryAddress(
        recoveryAddress: raw,
        signature: sig,
      );

      if (!mounted) return;
      ref.invalidate(vaultRecoveryProvider);
      await _showSuccess(raw, result.txHash);
      if (mounted) _controller.clear();
    } on ApiException catch (e) {
      if (mounted) _toast(_friendly(e.message));
    } catch (e) {
      if (mounted) _toast('Could not designate recovery address: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
              if (!EthereumProvider.available) ...[
                const SizedBox(height: 12),
                _warningCard(
                  'No wallet detected in this browser. Connect your wallet '
                  '(e.g. MetaMask) to sign the recovery designation.',
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