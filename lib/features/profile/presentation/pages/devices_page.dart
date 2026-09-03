import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';

class _Device {
  final String name;
  final String detail;
  final String location;
  final String lastActive;
  final IconData icon;
  final bool isCurrent;
  final bool loggedOut;

  const _Device({
    required this.name,
    required this.detail,
    required this.location,
    required this.lastActive,
    required this.icon,
    this.isCurrent = false,
    this.loggedOut = false,
  });
}

const _devices = [
  _Device(
    name: 'This Device',
    detail: 'Chrome on Linux',
    location: 'Lagos, Nigeria',
    lastActive: 'Active now',
    icon: Icons.laptop_mac,
    isCurrent: true,
  ),
  _Device(
    name: 'iPhone 15 Pro',
    detail: 'Globe Mint App',
    location: 'Abuja, Nigeria',
    lastActive: '2 hours ago',
    icon: Icons.phone_iphone,
  ),
  _Device(
    name: 'Samsung Galaxy S24',
    detail: 'Globe Mint App',
    location: 'Lagos, Nigeria',
    lastActive: '3 days ago',
    icon: Icons.smartphone,
  ),
  _Device(
    name: 'MacBook Pro',
    detail: 'Safari on macOS',
    location: 'Unknown location',
    lastActive: '2 weeks ago',
    icon: Icons.laptop_mac,
    loggedOut: true,
  ),
];

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final List<String> _loggedOut = [];

  void _logOut(String name) {
    setState(() => _loggedOut.add(name));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Devices')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
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
                        'You are signed in on 2 active devices',
                        style: context.typography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Signed-in Devices', style: context.typography.title),
              const SizedBox(height: 12),
              ...List.generate(_devices.length, (index) {
                final device = _devices[index];
                return _DeviceTile(
                  device: device,
                  isLoggedOut: _loggedOut.contains(device.name),
                  onLogout: () => _logOut(device.name),
                );
              }),
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
                      onPressed: () {
                        setState(() {
                          for (final d in _devices) {
                            if (!d.isCurrent && !_loggedOut.contains(d.name)) {
                              _loggedOut.add(d.name);
                            }
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Other devices logged out')),
                        );
                      },
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
    required this.isLoggedOut,
    required this.onLogout,
  });

  final _Device device;
  final bool isLoggedOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final dimmed = isLoggedOut || device.loggedOut;
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
              child: Icon(
                device.icon,
                color: dimmed ? AppColors.textTertiary : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        device.name,
                        style: context.typography.labelLarge.copyWith(
                          color: dimmed ? AppColors.textTertiary : null,
                        ),
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
                  Text(
                    device.detail,
                    style: context.typography.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLoggedOut
                        ? 'Logged out just now'
                        : '${device.location} • ${device.lastActive}',
                    style: context.typography.labelSmall,
                  ),
                ],
              ),
            ),
            if (!device.isCurrent && !isLoggedOut)
              TextButton(
                onPressed: onLogout,
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
    ).animate().fadeIn(delay: Duration(milliseconds: 100 + device.name.length * 40));
  }
}
