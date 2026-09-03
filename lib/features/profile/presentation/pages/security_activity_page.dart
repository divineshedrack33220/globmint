import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/app_button.dart';

enum _EventType { login, pinChange, device, alert, password }

class _SecurityEvent {
  final String title;
  final String detail;
  final String time;
  final _EventType type;

  const _SecurityEvent(this.title, this.detail, this.time, this.type);
}

const _events = [
  _SecurityEvent('New device login', 'iPhone 15 Pro — Abuja, Nigeria', '2 hrs ago', _EventType.login),
  _SecurityEvent('PIN changed', 'PIN was updated successfully', 'Yesterday', _EventType.pinChange),
  _SecurityEvent('Device added', 'Samsung Galaxy S24 was added', '3 days ago', _EventType.device),
  _SecurityEvent('Unusual activity blocked', 'Login attempt from Unknown location', '5 days ago', _EventType.alert),
  _SecurityEvent('Password changed', 'Password updated successfully', '1 week ago', _EventType.password),
  _SecurityEvent('New device login', 'Chrome on Linux — Lagos, Nigeria', '1 week ago', _EventType.login),
];

class SecurityActivityPage extends StatelessWidget {
  const SecurityActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Security Activity')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final event = _events[index];
            final (icon, color, muted) = _style(event.type);
            return AnimatedPress(
              onTap: () => _showDetail(context, event),
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
                        color: muted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: context.typography.labelLarge),
                          const SizedBox(height: 2),
                          Text(event.detail, style: context.typography.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(event.time, style: context.typography.labelSmall),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, _SecurityEvent event) {
    final (icon, color, muted) = _style(event.type);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(event.title, style: context.typography.headline),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(event.time, style: context.typography.bodySmall),
            ),
            const SizedBox(height: 24),
            Container(
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
                  Text('Event Type', style: context.typography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text(event.title, style: context.typography.labelLarge),
                  const Divider(color: AppColors.divider, height: 20),
                  Text('Details', style: context.typography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text(event.detail, style: context.typography.labelLarge),
                  const Divider(color: AppColors.divider, height: 20),
                  Text('Status', style: context.typography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.shield, color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Text('Completed', style: context.typography.labelLarge),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Close',
              onPressed: () => Navigator.pop(sheetContext),
              variant: AppButtonVariant.secondary,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _style(_EventType type) {
    switch (type) {
      case _EventType.login:
        return (Icons.login, AppColors.info, AppColors.infoMuted);
      case _EventType.pinChange:
        return (Icons.lock_reset, AppColors.primary, AppColors.primaryMuted);
      case _EventType.device:
        return (Icons.phone_android, AppColors.primary, AppColors.primaryMuted);
      case _EventType.alert:
        return (Icons.warning_amber, AppColors.warning, AppColors.warningMuted);
      case _EventType.password:
        return (Icons.password, AppColors.success, AppColors.successMuted);
    }
  }
}
