import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/models/models.dart';

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  bool _revoking = false;

  Future<void> _logOut(Device device) async {
    setState(() => _revoking = true);
    try {
      await ref.read(securityServiceProvider).revokeDevice(device.id);
      ref.invalidate(devicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${device.name} logged out')),
        );
      }
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  Future<void> _logOutAll() async {
    setState(() => _revoking = true);
    try {
      await ref.read(securityServiceProvider).revokeOtherDevices();
      ref.invalidate(devicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other devices logged out')),
        );
      }
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Devices')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              devicesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Couldn\u2019t load your devices.',
                      style: context.typography.bodyMedium,
                    ),
                  ),
                ),
                data: (devices) {
                  if (devices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No active devices.',
                          style: context.typography.bodyMedium,
                        ),
                      ),
                    );
                  }
                  final current = devices.where((d) => d.isCurrent).toList();
                  final countMsg = current.isEmpty || devices.length == 1
                      ? 'You are signed in on ${devices.length} active device${devices.length == 1 ? '' : 's'}'
                      : 'You are signed in on ${devices.length} active devices';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.successMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppColors.success),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                countMsg,
                                style: context.typography.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Signed-in Devices', style: context.typography.title),
                      const SizedBox(height: 12),
                      ...List.generate(devices.length, (index) {
                        final device = devices[index];
                        return _DeviceTile(
                          device: device,
                          revoking: _revoking,
                          onLogout: () => _logOut(device),
                        );
                      }).animate().fadeIn(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Security Tips', style: context.typography.title),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log out of devices you don\u2019t recognize',
                      style: context.typography.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We recommend reviewing your devices regularly to keep your account secure.',
                      style: context.typography.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      text: 'Log Out of All Other Devices',
                      onPressed: _revoking ? null : _logOutAll,
                      isLoading: _revoking,
                      variant: AppButtonVariant.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.revoking,
    required this.onLogout,
  });

  final Device device;
  final bool revoking;
  final VoidCallback onLogout;

  IconData get _icon {
    final name = device.name.toLowerCase();
    if (name.contains('iphone') || name.contains('phone')) return Icons.phone_iphone;
    if (name.contains('ipad')) return Icons.tablet_mac;
    if (name.contains('windows') || name.contains('linux')) return Icons.laptop_mac;
    if (name.contains('mac')) return Icons.laptop_mac;
    return Icons.devices_other;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(device.name, style: context.typography.labelLarge),
                      ),
                      if (device.isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('THIS', style: context.typography.labelSmall.copyWith(color: AppColors.primary, fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(device.detail, style: context.typography.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    '${device.ip?.split(':').first ?? 'Unknown location'} • ${DateFormatter.relative(device.lastActiveAt)}',
                    style: context.typography.labelSmall,
                  ),
                ],
              ),
            ),
            if (!device.isCurrent)
              TextButton(
                onPressed: revoking ? null : onLogout,
                child: Text(
                  'Log out',
                  style: context.typography.labelMedium.copyWith(
                    color: AppColors.destructive,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
