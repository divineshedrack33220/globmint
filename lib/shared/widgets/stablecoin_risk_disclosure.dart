import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';

/// Stablecoin risk + custody disclosure shown wherever real money moves
/// (top-up, withdrawal). Keeps the account holder informed that the vault is
/// self-custodial USDC, not a bank.
class StablecoinRiskDisclosure extends StatelessWidget {
  const StablecoinRiskDisclosure({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text('Read before you send money', style: context.typography.title),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your vault holds USDC, a stablecoin issued by Circle (a private '
            'company), not by Globmint. USDC is expected to stay close to '
            'one US dollar but is not a government currency: it may depeg or '
            'become hard to redeem if Circle or the market is stressed.',
            style: context.typography.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Globmint is self-custodial: your money sits in a smart contract '
            'you can see on-chain, not in our bank account. We hold no '
            'custody, and there is no bank-deposit guarantee.',
            style: context.typography.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Value is shown in NGN at the current rate for convenience only. '
            'Withdraw and one-off payments are subject to a time-lock when '
            'they exceed the safe threshold.',
            style: context.typography.bodySmall,
          ),
        ],
      ),
    );
  }
}