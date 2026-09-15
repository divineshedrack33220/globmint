import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';

class WalletConnectPairingDialog extends StatefulWidget {
  const WalletConnectPairingDialog({
    super.key,
    required this.pairingUris,
    this.onOpenWallet,
  });

  final Stream<String> pairingUris;
  final Future<bool> Function()? onOpenWallet;

  static Future<bool?> show(
    BuildContext context, {
    required Stream<String> pairingUris,
    Future<bool> Function()? onOpenWallet,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WalletConnectPairingDialog(
        pairingUris: pairingUris,
        onOpenWallet: onOpenWallet,
      ),
    );
  }

  @override
  State<WalletConnectPairingDialog> createState() =>
      _WalletConnectPairingDialogState();
}

class _WalletConnectPairingDialogState
    extends State<WalletConnectPairingDialog> {
  late final StreamSubscription<String> _sub;
  String? _uri;

  @override
  void initState() {
    super.initState();
    _sub = widget.pairingUris.listen((uri) {
      if (mounted) setState(() => _uri = uri);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showOpen = widget.onOpenWallet != null && !kIsWeb;
    final uri = _uri;
    return AlertDialog(
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Scan with your wallet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            showOpen
                ? 'Open the wallet app you want to sign with, tap "Scan", '
                    'and point it at this code.'
                : 'Open your wallet app on another device, tap "Scan", '
                    'and point it at this code.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: uri != null
                ? QrImageView(
                    data: uri,
                    version: QrVersions.auto,
                    size: 168,
                    backgroundColor: Colors.white,
                  )
                : const SizedBox(
                    width: 168,
                    height: 168,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for a WalletConnect pairing URI…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (showOpen)
          TextButton(
            onPressed: () async {
              await widget.onOpenWallet!.call();
            },
            child: const Text('Open wallet app'),
          ),
      ],
    );
  }
}
