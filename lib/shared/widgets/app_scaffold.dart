import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class ScaffoldWithNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: Stack(
        children: [
          // Main content with top/bottom padding for fixed bars
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            bottom: 70,
            child: navigationShell,
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
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
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
                  children: List.generate(_destinations.length, (index) {
                    final dest = _destinations[index];
                    final isActive = index == currentIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          navigationShell.goBranch(
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