import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/staggered_modal.dart';
import '../../../legal/data/legal_documents.dart';

class HelpCenterSheet extends StatelessWidget {
  const HelpCenterSheet({super.key, this.onViewAllFaqs});

  /// Open the full FAQ page (the sheet cannot push routes itself).
  final VoidCallback? onViewAllFaqs;

  /// Curated subset of the canonical FAQ (see LegalDocuments.faq): the
  /// questions new users ask most. The full list lives on /legal/faq.
  static const _featured = [0, 2, 4, 5, 7, 12];

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
                  Clipboard.setData(
                      const ClipboardData(text: 'support@globemint.app'));
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('support@globemint.app copied')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ContactOption(
                icon: Icons.quiz_outlined,
                title: 'FAQ',
                subtitle: 'Browse all frequently asked questions',
                onTap: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                  onViewAllFaqs?.call();
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
      for (final i in _featured) _FAQ(LegalDocuments.faq[i].question, LegalDocuments.faq[i].answer),
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
          text: 'View all FAQs',
          onPressed: () {
            Navigator.pop(context);
            onViewAllFaqs?.call();
          },
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Contact Support',
          onPressed: () => _showContactSupport(context),
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
