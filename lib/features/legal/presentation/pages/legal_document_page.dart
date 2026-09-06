import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../data/legal_documents.dart';

/// Full-screen reader for a sectioned legal document (Privacy Policy, Terms).
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last updated: ${LegalDocuments.lastUpdated} · Contact: ${LegalDocuments.supportEmail}',
                style: context.typography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              for (final section in sections) ...[
                Text(section.title, style: context.typography.title),
                const SizedBox(height: 8),
                for (final paragraph in section.paragraphs) ...[
                  Text(paragraph, style: context.typography.bodyMedium),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
