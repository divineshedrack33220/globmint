import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/staggered_modal.dart';

class HelpCenterSheet extends StatelessWidget {
  const HelpCenterSheet({super.key});

  void _showContactSupport(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact Support', style: context.typography.headline),
              const SizedBox(height: 8),
              Text(
                'We\u2019re here to help. Reach us any time.',
                style: context.typography.bodyMedium,
              ),
              const SizedBox(height: 20),
              _ContactOption(
                icon: Icons.mail_outline,
                title: 'Email us',
                subtitle: 'support@globemint.app',
                onTap: () {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('support@globemint.app copied')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ContactOption(
                icon: Icons.chat_outlined,
                title: 'Live chat',
                subtitle: 'Instant replies, 24/7',
                onTap: () {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support chat opening...')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ContactOption(
                icon: Icons.info_outline,
                title: 'FAQ',
                subtitle: 'Browse the help center',
                onTap: () {
                  Navigator.pop(dialogContext);
                },
              ),
              const SizedBox(height: 20),
              AppButton(
                text: 'Close',
                onPressed: () => Navigator.pop(dialogContext),
                variant: AppButtonVariant.secondary,
                isExpanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faqs = [
      _FAQ(
        'How do I add money to my account?',
        'Go to Home → Quick Actions → Add Money. Enter the amount in NGN or USDT, confirm, and the funds will appear in your available balance instantly.',
      ),
      _FAQ(
        'How do I convert NGN to USDT?',
        'Use the "Save" quick action or go to Savings → Convert. Enter the NGN amount, review the exchange rate and fee, then confirm. The USDT goes directly to your savings.',
      ),
      _FAQ(
        'How long do withdrawals take?',
        'Withdrawals to your linked bank account are processed within 5 minutes. You\'ll receive a notification when the transfer is complete.',
      ),
      _FAQ(
        'What are the fees?',
        'Conversions: 1.5% fee. Bank transfers: ₦10 flat fee. Withdrawals: 1% fee. Adding money: free. All fees are shown before you confirm.',
      ),
      _FAQ(
        'Is my money safe?',
        'This is a prototype demo app. No real money moves. In a production version, funds would be held by licensed partners with bank-grade encryption.',
      ),
      _FAQ(
        'How do I contact support?',
        'Email: support@globemint.app | In-app chat: tap the help icon on any screen. Response time: under 24 hours.',
      ),
    ];

    return StaggeredBottomSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      header: Text('Help Center', style: context.typography.headline),
      children: [
        Text(
          'Find answers to common questions',
          style: context.typography.bodyMedium,
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < faqs.length; i++)
          _FAQTile(faq: faqs[i]),
        const SizedBox(height: 16),
        AppButton(
          text: 'Contact Support',
          onPressed: () {
            Navigator.pop(context);
            _showContactSupport(context);
          },
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FAQ {
  final String question;
  final String answer;
  const _FAQ(this.question, this.answer);
}

class _FAQTile extends StatefulWidget {
  const _FAQTile({required this.faq});
  final _FAQ faq;

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: context.typography.labelLarge,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.faq.answer, style: context.typography.bodyMedium),
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.typography.labelLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.typography.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
