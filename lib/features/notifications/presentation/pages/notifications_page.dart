import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../shared/models/models.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await ref.read(securityServiceProvider).markNotificationRead(n.id);
      ref.invalidate(notificationsProvider);
    } catch (_) {
      // best-effort; ignore network/state failures
    }
  }

  Future<void> _markAll() async {
    try {
      await ref.read(securityServiceProvider).markAllNotificationsRead();
      ref.invalidate(notificationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(notificationsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (data != null && data.unread > 0)
            TextButton(
              onPressed: _markAll,
              child: Text(
                'Mark all read',
                style: context.typography.labelMedium.copyWith(color: AppColors.primary),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ref.watch(notificationsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_off_outlined, color: AppColors.textTertiary, size: 48),
                  const SizedBox(height: 12),
                  Text('Couldn\u2019t load notifications', style: context.typography.title),
                ],
              ),
            ),
          ),
          data: (d) {
            final notifications = d.items;
            if (notifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_off_outlined, color: AppColors.textTertiary, size: 48),
                      const SizedBox(height: 12),
                      Text('No notifications yet', style: context.typography.title),
                    ],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    d.unread == 0
                        ? 'You\u2019re all caught up'
                        : '${d.unread} unread notification${d.unread == 1 ? '' : 's'}',
                    style: context.typography.bodyMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 64,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => _markRead(n),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  (IconData, Color, Color) get _style {
    final Color bg;
    final Color color;
    late final IconData icon;
    switch (notification.category) {
      case 'deposit':
        icon = Icons.arrow_downward;
        color = const Color(0xFF22C55E);
        bg = const Color(0xFF052E16);
      case 'transfer':
        icon = Icons.send;
        color = const Color(0xFF60A5FA);
        bg = const Color(0xFF172554);
      case 'conversion':
        icon = Icons.currency_exchange;
        color = const Color(0xFFFFD21F);
        bg = const Color(0xFF4A4000);
      case 'security':
        icon = Icons.shield_outlined;
        color = const Color(0xFFF59E0B);
        bg = const Color(0xFF451A03);
      default:
        icon = Icons.account_balance_wallet_outlined;
        color = const Color(0xFFFFD21F);
        bg = const Color(0xFF4A4000);
    }
    return (icon, color, bg);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, iconBg) = _style;
    return AnimatedPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: context.typography.labelLarge.copyWith(
                            color: notification.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5, left: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(notification.body, style: context.typography.bodySmall),
                  const SizedBox(height: 4),
                  Text(DateFormatter.relative(notification.date), style: context.typography.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
