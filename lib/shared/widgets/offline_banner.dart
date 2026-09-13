import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';

/// Slim full-width banner shown while the app cannot reach the backend.
/// Collapses to zero height the moment connectivity returns, so the content
/// (and fixed bars) sit flush again without layout jumps.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = !ref.watch(connectivityServiceProvider).online;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: offline ? 34 : 0,
      color: offline ? AppColors.warning : Colors.transparent,
      child: offline
          ? Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    size: 14,
                    color: AppColors.backgroundDeep,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'No internet connection — showing last synced data',
                    style: context.typography.labelSmall.copyWith(
                      color: AppColors.backgroundDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
