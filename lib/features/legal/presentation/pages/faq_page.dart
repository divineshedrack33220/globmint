import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../data/legal_documents.dart';

/// Frequently asked questions, one expandable answer per question.
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = LegalDocuments.faq;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: entries.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Still stuck? Contact ${LegalDocuments.supportEmail}.',
                  style: context.typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }
            final entry = entries[index - 1];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(entry.question, style: context.typography.labelLarge),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(entry.answer, style: context.typography.bodyMedium),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
