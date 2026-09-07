import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../shared/services/announcement_service.dart';

/// Dismissible operator announcements. Hidden entirely when there is nothing
/// active. Dismissals persist on-device per announcement id.
class AnnouncementSlot extends StatefulWidget {
  const AnnouncementSlot({super.key});

  @override
  State<AnnouncementSlot> createState() => _AnnouncementSlotState();
}

class _AnnouncementSlotState extends State<AnnouncementSlot> {
  List<Announcement> _active = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = await AnnouncementService.load();
    final active = await service.active();
    if (mounted) {
      setState(() {
        _active = active;
        _loaded = true;
      });
    }
  }

  Future<void> _dismiss(Announcement a) async {
    final service = await AnnouncementService.load();
    await service.dismiss(a.id);
    if (mounted) {
      setState(() => _active = _active.where((x) => x.id != a.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _active.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final a in _active) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.title, style: context.typography.labelLarge),
                    ),
                    GestureDetector(
                      onTap: () => _dismiss(a),
                      child: const Icon(Icons.close,
                          color: AppColors.textSecondary, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(a.body, style: context.typography.bodyMedium),
                if (a.actionLabel != null && a.actionRoute != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.push(a.actionRoute!),
                    child: Text(
                      a.actionLabel!,
                      style: context.typography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
