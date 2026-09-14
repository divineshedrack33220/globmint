import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/services/api_client.dart';
import '../../../../shared/services/wallet_service.dart';
import '../widgets/wallet_connect_button.dart';

class SecurityCenterPage extends ConsumerStatefulWidget {
  const SecurityCenterPage({super.key});

  @override
  ConsumerState<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends ConsumerState<SecurityCenterPage> {
  bool _twoFactor = false;
  bool _updatingTwoFactor = false;
  bool _biometric = false;
  bool _loginAlerts = true;

  @override
  void initState() {
    super.initState();
    _twoFactor = ref.read(authServiceProvider).currentUser?.twoFactorEnabled ?? false;
  }

  Future<void> _toggleTwoFactor(bool enable) async {
    if (_updatingTwoFactor) return;
    setState(() => _updatingTwoFactor = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (enable) {
        final setup = await auth.totpSetup();
        if (!mounted) return;
        final code = await _collectCode(context, 'Enable 2FA', setup['secret'] ?? '');
        if (code == null) return;
        await auth.enableTwoFactor(code);
        if (!mounted) return;
        setState(() => _twoFactor = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication enabled')),
        );
      } else {
        final code = await _collectCode(context, 'Disable 2FA', '');
        if (!mounted) return;
        if (code == null) return;
        final pin = await _collectPin(context);
        if (pin == null) return;
        await auth.disableTwoFactor(code: code, pin: pin);
        if (!mounted) return;
        setState(() => _twoFactor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication disabled')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _updatingTwoFactor = false);
    }
  }

  Future<String?> _collectCode(BuildContext context, String title, String secret) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (secret.isNotEmpty) ...[
                Text(
                  'Scan this in your authenticator app (or enter it manually):',
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 8),
                SelectableText(secret, style: context.typography.bodyMedium),
                const SizedBox(height: 12),
              ],
              AppTextField(
                label: '6-digit code',
                hint: 'Code from authenticator',
                controller: controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<String?> _collectPin(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter your transaction PIN'),
        content: AppTextField(
          label: 'PIN',
          hint: '6-digit PIN',
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final chain = wallet.chainId ?? 0;

    final Color iconColor;
    final IconData icon;
    final String title;
    final String? subtitle;
    if (wallet.status == WalletConnectionStatus.connected) {
      iconColor = AppColors.success;
      icon = Icons.account_balance_wallet_outlined;
      title = _shortenAddress(wallet.address ?? '');
      subtitle = 'Chain $chain — signs withdrawals in your wallet';
    } else if (wallet.status == WalletConnectionStatus.wrongChain) {
      iconColor = AppColors.warning;
      icon = Icons.warning_amber_rounded;
      title = 'Wrong network';
      subtitle = 'Switch your wallet to the supported chain.';
    } else if (wallet.status == WalletConnectionStatus.connecting) {
      iconColor = AppColors.primary;
      icon = Icons.sync;
      title = 'Connecting…';
      subtitle = null;
    } else {
      iconColor = AppColors.textSecondary;
      icon = Icons.link;
      title = wallet.hasWallet ? 'Not connected' : 'No wallet detected';
      subtitle = wallet.hasWallet
          ? 'Connect a wallet to sign withdrawals yourself.'
          : 'Install MetaMask in this browser to sign withdrawals yourself.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.typography.bodyLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: context.typography.bodySmall),
                    ],
                    if (wallet.error != null) ...[
                      const SizedBox(height: 2),
Text(
                          wallet.error!,
                          style: context.typography.bodySmall.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WalletConnectButton(
            expectedChainId:
                ref.read(depositInfoProvider).valueOrNull?.chainId,
          ),
        ],
      ),
    );
  }

  static String _shortenAddress(String addr) {
    if (addr.isEmpty) return '';
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }

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
              Text('Connected Wallet', style: context.typography.title),
              const SizedBox(height: 12),
              _buildWalletCard(context),
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
                      onChanged: (v) => _toggleTwoFactor(v),
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
      activeTrackColor: AppColors.primarySubtle,
      activeThumbColor: AppColors.primary,
      inactiveThumbColor: AppColors.textTertiary,
      inactiveTrackColor: AppColors.surfaceHighlight,
      dense: true,
    );
  }
}
