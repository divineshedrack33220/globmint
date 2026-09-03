import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';

class SecurityCenterPage extends StatefulWidget {
  const SecurityCenterPage({super.key});

  @override
  State<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends State<SecurityCenterPage> {
  bool _twoFactor = true;
  bool _biometric = false;
  bool _loginAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Security Center')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Security score
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    Text('SECURITY SCORE', style: context.typography.labelMedium),
                    const SizedBox(height: 8),
                    Text('70%', style: context.typography.amountHeroHighlight),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.7,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceHighlight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enable biometrics to improve your score',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Account Protection', style: context.typography.title),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.smartphone,
                      title: 'Two-Factor Authentication',
                      subtitle: 'Require a code on new logins',
                      value: _twoFactor,
                      onChanged: (v) => setState(() => _twoFactor = v),
                    ),
                    const Divider(color: AppColors.divider, height: 1, indent: 52),
                    _SwitchTile(
                      icon: Icons.fingerprint,
                      title: 'Biometric Login',
                      subtitle: 'Use fingerprint or face to unlock',
                      value: _biometric,
                      onChanged: (v) => setState(() => _biometric = v),
                    ),
                    const Divider(color: AppColors.divider, height: 1, indent: 52),
                    _SwitchTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Login Alerts',
                      subtitle: 'Get notified of new device logins',
                      value: _loginAlerts,
                      onChanged: (v) => setState(() => _loginAlerts = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Change Security', style: context.typography.title),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                      title: Text('Change PIN', style: context.typography.bodyLarge),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                      onTap: () => context.push('/profile/change-pin'),
                    ),
                    const Divider(color: AppColors.divider, height: 1, indent: 52),
                    ListTile(
                      leading: const Icon(Icons.password, color: AppColors.textSecondary),
                      title: Text('Change Password', style: context.typography.bodyLarge),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                      onTap: () => context.push('/profile/change-password'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Save Changes',
                isExpanded: true,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Security settings saved')),
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(title, style: context.typography.bodyLarge),
      subtitle: Text(subtitle, style: context.typography.bodySmall),
      activeTrackColor: AppColors.primaryMuted,
      activeThumbColor: AppColors.primary,
      inactiveThumbColor: AppColors.textTertiary,
      inactiveTrackColor: AppColors.surfaceHighlight,
      dense: true,
    );
  }
}
