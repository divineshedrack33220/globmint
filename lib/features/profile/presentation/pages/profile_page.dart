import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius_tokens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/mock_data.dart';
import 'help_center_sheet.dart';
import 'terms_privacy_sheet.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockData.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: context.typography.display),
              const SizedBox(height: 24),
              // User Info
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          user.initials,
                          style: context.typography.amountLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(user.fullName, style: context.typography.headline),
                    const SizedBox(height: 4),
                    Text(user.email, style: context.typography.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Settings
              _SettingsSection(
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    onTap: () => context.push('/profile/personal-info'),
                  ),
                  _SettingsTile(
                    icon: Icons.credit_card,
                    title: 'Bank Accounts',
                    onTap: () => context.push('/profile/bank-accounts'),
                  ),
                  _SettingsTile(
                    icon: Icons.people_outline,
                    title: 'Beneficiaries',
                    onTap: () => context.push('/profile/beneficiaries'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Security',
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Security Center',
                    onTap: () => context.push('/profile/security-center'),
                  ),
                  _SettingsTile(
                    icon: Icons.phone_android,
                    title: 'Devices',
                    onTap: () => context.push('/profile/devices'),
                  ),
                  _SettingsTile(
                    icon: Icons.history,
                    title: 'Security Activity',
                    onTap: () => context.push('/profile/security-activity'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Support',
                children: [
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () => _showHelpCenter(context),
                  ),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms & Privacy',
                    onTap: () => _showTermsPrivacy(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Logout
              Center(
                child: AnimatedPress(
                  onTap: () => _confirmSignOut(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      'Sign Out',
                      style: context.typography.labelLarge.copyWith(
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'v1.0.0',
                  style: context.typography.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const HelpCenterSheet(),
    );
  }

  void _showTermsPrivacy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const TermsPrivacySheet(),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Sign out?',
      details: [
        ConfirmationDetail(label: 'You will be logged out', value: ''),
      ],
      confirmText: 'Sign Out',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.go('/welcome');
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.typography.labelMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: context.typography.bodyLarge),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
