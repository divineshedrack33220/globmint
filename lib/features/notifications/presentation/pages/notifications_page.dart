import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_press.dart';

class _AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool read;

  _AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.read,
  });
}

final _notifications = <_AppNotification>[
  _AppNotification(
    id: 'notif_001',
    title: 'Deposit successful',
    body: '₦50,000.00 was added to your savings.',
    date: DateTime(2026, 9, 3, 9, 30),
    icon: Icons.arrow_downward,
    iconColor: Color(0xFF22C55E),
    iconBg: Color(0xFF052E16),
    read: false,
  ),
  _AppNotification(
    id: 'notif_002',
    title: 'Conversion completed',
    body: 'Your NGN was converted to USDT successfully.',
    date: DateTime(2026, 9, 2, 16, 45),
    icon: Icons.currency_exchange,
    iconColor: Color(0xFFFFD21F),
    iconBg: Color(0xFF4A4000),
    read: false,
  ),
  _AppNotification(
    id: 'notif_003',
    title: 'Security alert',
    body: 'New login detected from Chrome on Linux.',
    date: DateTime(2026, 9, 2, 8, 15),
    icon: Icons.shield_outlined,
    iconColor: Color(0xFFF59E0B),
    iconBg: Color(0xFF451A03),
    read: true,
  ),
  _AppNotification(
    id: 'notif_004',
    title: 'Transfer sent',
    body: 'You sent ₦120,000.00 to Aisha Bello.',
    date: DateTime(2026, 9, 1, 13, 20),
    icon: Icons.send,
    iconColor: Color(0xFF60A5FA),
    iconBg: Color(0xFF172554),
    read: true,
  ),
  _AppNotification(
    id: 'notif_005',
    title: 'Welcome to Globmint',
    body: 'Your digital savings vault is ready.',
    date: DateTime(2026, 8, 30, 10, 0),
    icon: Icons.account_balance_wallet_outlined,
    iconColor: Color(0xFFFFD21F),
    iconBg: Color(0xFF4A4000),
    read: true,
  ),
];

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _markAllRead = false;
  final Set<String> _read = {};

  bool _isRead(_AppNotification n) => _markAllRead || _read.contains(n.id);

  void _markRead(_AppNotification n) {
    if (_isRead(n)) return;
    setState(() => _read.add(n.id));
  }

  void _markAll() {
    setState(() => _markAllRead = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  void _clearAll() {
    setState(() {
      _markAllRead = false;
      _read.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !_isRead(n)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    unreadCount == 0
                        ? 'You\u2019re all caught up'
                        : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                    style: context.typography.bodyMedium,
                  ),
                  const Spacer(),
                  if (_notifications.any((n) => !_isRead(n)))
                    TextButton(
                      onPressed: _clearAll,
                      child: Text(
                        'Clear all',
                        style: context.typography.labelMedium.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 64,
                  color: AppColors.divider,
                ),
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  return _NotificationTile(
                    notification: n,
                    isRead: _isRead(n),
                    onTap: () => _markRead(n),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final _AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                color: notification.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(notification.icon, color: notification.iconColor, size: 22),
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
                            color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
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
