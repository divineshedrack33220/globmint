import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/staggered_modal.dart';

class TermsPrivacySheet extends StatelessWidget {
  const TermsPrivacySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return StaggeredBottomSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      header: Text('Terms & Privacy', style: context.typography.headline),
      headerActions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Last updated: September 2026',
            style: context.typography.bodySmall,
          ),
        ),
      ],
      children: [
        _Section(
          title: '1. Acceptance of Terms',
          content: 'By using Globe Mint, you agree to these Terms of Service and our Privacy Policy. If you do not agree, please do not use the app.',
        ),
        _Section(
          title: '2. Prototype Notice',
          content: 'Globe Mint is currently a prototype/demo application. No real money is moved, stored, or transferred. All balances, transactions, and conversions are simulated for demonstration purposes only.',
        ),
        _Section(
          title: '3. Account Registration',
          content: 'You must provide accurate information when creating an account. You are responsible for maintaining the confidentiality of your PIN and login credentials. Notify us immediately of any unauthorized use.',
        ),
        _Section(
          title: '4. Savings & Conversions',
          content: 'Savings balances and USDT conversions are simulated. Exchange rates are mock data and do not reflect real market rates. No actual blockchain or banking operations occur.',
        ),
        _Section(
          title: '5. Transfers & Payments',
          content: 'Bank transfers and beneficiary payments are simulated. No real funds leave or enter any bank account. All transactions are for UI/UX demonstration only.',
        ),
        _Section(
          title: '6. Data Collection',
          content: 'In this prototype, we collect minimal data: name, email, phone number, and simulated transaction history. No real financial data, KYC documents, or biometric data is collected.',
        ),
        _Section(
          title: '7. Data Usage',
          content: 'Your data is used solely to provide the demo experience. We do not sell, share, or monetize your data. In a production version, data would be handled per applicable regulations (NDPR, GDPR).',
        ),
        _Section(
          title: '8. Security',
          content: 'The app uses PIN authentication and simulated biometric login. In production, we would implement bank-grade encryption, 2FA, and regular security audits.',
        ),
        _Section(
          title: '9. Limitation of Liability',
          content: 'This prototype is provided "as is" without warranties. We are not liable for any damages arising from use of this demo. This is not financial advice.',
        ),
        _Section(
          title: '10. Changes to Terms',
          content: 'We may update these terms. Continued use after changes constitutes acceptance. For the prototype, changes are infrequent.',
        ),
        _Section(
          title: '11. Contact',
          content: 'Questions about these terms? Email: legal@globemint.app',
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.typography.labelLarge),
          const SizedBox(height: 8),
          Text(content, style: context.typography.bodyMedium),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0, duration: 300.ms);
  }
}