import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/events_service.dart';

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    (icon: Icons.savings_outlined, selectedIcon: Icons.savings, label: 'Savings'),
    (icon: Icons.send_outlined, selectedIcon: Icons.send, label: 'Pay'),
    (icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Activity'),
    (icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  Timer? _notifPoll;
  ProviderSubscription<AsyncValue<UserEvent>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    // Keep the notification badge/inbox fresh without a push channel.
    _notifPoll = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidate(notificationsProvider);
    });
    // Balance/vault/transaction updates are pushed over SSE; refresh the
    // relevant providers immediately when one arrives instead of polling.
    _eventsSub = ref.listenManual<AsyncValue<UserEvent>>(
      eventsStreamProvider,
      (_, next) {
        final event = next.valueOrNull;
        if (event != null) _onEvent(event);
      },
    );
  }

  void _onEvent(UserEvent event) {
    switch (event.kind) {
      case EventKind.account:
        ref.invalidate(accountSummaryProvider);
      case EventKind.vault:
        ref.invalidate(vaultStatusProvider);
        ref.invalidate(accountSummaryProvider);
      case EventKind.transactions:
        ref.invalidate(transactionsProvider);
        ref.invalidate(recentTransactionsProvider);
      case EventKind.all:
      // `connected` events also trigger a full refresh so the UI catches up
      // on anything missed while disconnected.
        ref.invalidate(accountSummaryProvider);
        ref.invalidate(vaultStatusProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(recentTransactionsProvider);
    }
  }

  @override
  void dispose() {
    _notifPoll?.cancel();
    _eventsSub?.close();
    super.dispose();
  }

  int get _unread =>
      ref.watch(notificationsProvider).maybeWhen(
        data: (data) => data.unread,
        orElse: () => 0,
      );

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final unread = _unread;

    return Scaffold(
      body: Stack(
        children: [
          // Main content with top/bottom padding for fixed bars
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            bottom: 70,
            child: widget.navigationShell,
          ),
          // Fixed top nav bar - minimal branding only
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundDeep,
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // App brand
                      Container(
                        width: 28,
                        height: 28,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Spacer(),
                      // Notifications (always visible)
                      IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none, color: AppColors.textSecondary, size: 24),
                            if (unread > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  constraints: const BoxConstraints(minWidth: 16),
                                  decoration: const ShapeDecoration(
                                    color: AppColors.primary,
                                    shape: StadiumBorder(),
                                  ),
                                  child: Center(
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: const TextStyle(
                                        color: AppColors.primaryForeground,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () => context.push('/notifications'),
                        tooltip: 'Notifications',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Fixed bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                height: 70,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundDeep,
                  border: Border(
                    top: BorderSide(color: AppColors.borderSubtle, width: 1),
                  ),
                ),
                child: Row(
                  children: List.generate(ScaffoldWithNavBar._destinations.length, (index) {
                    final dest = ScaffoldWithNavBar._destinations[index];
                    final isActive = index == currentIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          widget.navigationShell.goBranch(
                            index,
                            initialLocation: index == currentIndex,
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primaryMuted
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isActive ? dest.selectedIcon : dest.icon,
                                size: 20,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dest.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    isActive ? FontWeight.w600 : FontWeight.w500,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}