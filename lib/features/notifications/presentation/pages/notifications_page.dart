import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_press.dart';
import '../../../../shared/models/models.dart';

/// Icon + colors per notification category. Shared by the list tile and the
/// detail sheet so both always agree.
(IconData, Color, Color) notificationStyle(String category) {
  final Color bg;
  final Color color;
  late final IconData icon;
  switch (category) {
    case 'deposit':
      icon = Icons.arrow_downward;
      color = const Color(0xFF22C55E);
      bg = const Color(0xFF052E16);
    case 'withdrawal':
      icon = Icons.arrow_upward;
      color = const Color(0xFFF87171);
      bg = const Color(0xFF450A0A);
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

String notificationCategoryLabel(String category) {
  switch (category) {
    case 'deposit':
      return 'Deposit';
    case 'withdrawal':
      return 'Withdrawal';
    case 'transfer':
      return 'Transfer';
    case 'conversion':
      return 'Conversion';
    case 'security':
      return 'Security';
    default:
      return 'General';
  }
}

/// Categories tied to money movement: their summary offers a jump to Activity.
bool notificationHasActivity(String category) {
  return category == 'deposit' ||
      category == 'withdrawal' ||
      category == 'transfer' ||
      category == 'conversion';
}

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

  Future<void> _openSummary(AppNotification n) async {
    await _markRead(n);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _NotificationSummarySheet(notification: n),
    );
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
                        onTap: () => _openSummary(n),
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

  (IconData, Color, Color) get _style =>
      notificationStyle(notification.category);

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

/// Full summary of one notification: icon, category, title, timestamp, and
/// the complete message. Money notifications add a jump to Activity.
class _NotificationSummarySheet extends StatelessWidget {
  const _NotificationSummarySheet({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final (icon, color, iconBg) = notificationStyle(notification.category);
    final navigator = Navigator.of(context);
    return Dialog.fullscreen(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => navigator.pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Text('Notification', style: context.typography.title),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        notificationCategoryLabel(notification.category),
                        style: context.typography.labelSmall.copyWith(color: color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        DateFormatter.full(notification.date),
                        style: context.typography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(notification.title, style: context.typography.headline),
                    const SizedBox(height: 12),
                    Text(
                      notification.body,
                      style: context.typography.bodyMedium.copyWith(
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (notificationHasActivity(notification.category)) ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            navigator.pop();
                            GoRouter.of(context).go('/activity');
                          },
                          child: const Text('View activity'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
