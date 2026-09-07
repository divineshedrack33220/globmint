import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';

/// Collapsible privacy messaging used across onboarding and the add-money
/// screen. Communicates that the vault stores balances against one-way
/// commitments (keccak256(address, salt)) rather than raw addresses, so
/// balances cannot be looked up on-chain.
class PrivacyNotice extends StatelessWidget {
  const PrivacyNotice({super.key, this.compact = false});

  /// When true renders a slim callout without the full body copy.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  compact ? 'Privacy-protected' : 'How your deposits stay private',
                  style: context.typography.title,
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              'Your vault balance is stored against a one-way commitment — a '
              'hash of your wallet address and a private random salt — rather '
              'than your raw address. Anyone on-chain can see that a deposit '
              'happened and its amount, but they cannot tie your balance to '
              'your wallet address or look up how much you hold on the chain.',
              style: context.typography.bodySmall.copyWith(
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Sending, receiving and withdrawing work exactly as usual — the '
              'extra privacy math happens behind the scenes on the contract '
              'and in the vault indexer.',
              style: context.typography.bodySmall.copyWith(
                  color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small trust chip shown when the server confirms privacy mode is active
/// (`privacy_enabled` on the deposit-info payload).
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryOverlay,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined,
              color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            'Privacy-protected balance',
            style: context.typography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}