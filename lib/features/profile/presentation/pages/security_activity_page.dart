import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/models/models.dart';

class SecurityActivityPage extends ConsumerWidget {
  const SecurityActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(securityEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Security Activity')),
      body: SafeArea(
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Couldn\u2019t load security activity.',
              style: context.typography.bodyMedium,
            ),
          ),
          data: (events) {
            if (events.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.textTertiary, size: 48),
                      const SizedBox(height: 12),
                      Text('No security activity yet', style: context.typography.title),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
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
                        Text(
                          _timeLabel(event.time),
                          style: context.typography.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  void _showDetail(BuildContext context, SecurityEvent event) {
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
            Center(child: Text(event.title, style: context.typography.headline)),
            const SizedBox(height: 4),
            Center(child: Text(_timeLabel(event.time), style: context.typography.bodySmall)),
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
                  Text('Event', style: context.typography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text(event.title, style: context.typography.labelLarge),
                  const Divider(color: AppColors.divider, height: 20),
                  Text('Details', style: context.typography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text(event.detail, style: context.typography.labelLarge),
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

  (IconData, Color, Color) _style(String type) {
    switch (type) {
      case 'login':
        return (Icons.login, AppColors.info, AppColors.infoMuted);
      case 'register':
        return (Icons.person_add_alt_1, AppColors.success, AppColors.successMuted);
      case 'pin_change':
        return (Icons.lock_reset, AppColors.primary, AppColors.primaryMuted);
      case 'password':
        return (Icons.password, AppColors.success, AppColors.successMuted);
      case 'logout':
        return (Icons.logout, AppColors.infoMuted, AppColors.primaryMuted);
      case 'device':
        return (Icons.phone_android, AppColors.primary, AppColors.primaryMuted);
      case 'alert':
        return (Icons.warning_amber, AppColors.warning, AppColors.warningMuted);
      default:
        return (Icons.shield, AppColors.info, AppColors.infoMuted);
    }
  }
}
