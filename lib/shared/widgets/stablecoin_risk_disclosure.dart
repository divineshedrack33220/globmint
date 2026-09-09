import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/app_info_dialog.dart';

/// Stablecoin risk + custody disclosure shown wherever real money moves
/// (top-up, withdrawal). Rendered as a single tappable line; the full text is
/// shown on demand in a dialog so screens never become walls of instructions.
class StablecoinRiskDisclosure extends StatelessWidget {
  const StablecoinRiskDisclosure({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => InfoDialog.show(
        context: context,
        title: 'Stablecoin & custody',
        icon: Icons.info_outline,
        body: [
          _paragraph(
            context,
            'Your vault holds USDC, a stablecoin issued by Circle (a private '
            'company), not by Globmint. USDC is expected to stay close to one '
            'US dollar but is not a government currency: it may depeg or '
            'become hard to redeem if Circle or the market is stressed.',
          ),
          _paragraph(
            context,
            'Globmint is self-custodial: your money sits in a smart contract '
            'you can see on-chain, not in our bank account. We hold no '
            'custody, and there is no bank-deposit guarantee.',
          ),
          _paragraph(
            context,
            'Value is shown in NGN at the current rate for convenience only. '
            'Withdraw and one-off payments are subject to a time-lock when '
            'they exceed the safe threshold.',
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Stablecoin & custody disclosure',
                style: context.typography.bodySmall,
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: context.typography.bodySmall),
    );
  }
}