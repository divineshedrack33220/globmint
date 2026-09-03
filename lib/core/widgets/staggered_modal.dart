import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class StaggeredBottomSheet extends StatelessWidget {
  const StaggeredBottomSheet({
    super.key,
    this.initialChildSize = 0.6,
    this.maxChildSize = 0.9,
    this.minChildSize = 0.4,
    this.header,
    this.headerActions,
    this.dragHandleColor,
    required this.children,
  });

  final double initialChildSize;
  final double maxChildSize;
  final double minChildSize;
  final Widget? header;
  final List<Widget>? headerActions;
  final Color? dragHandleColor;
  final List<Widget> children;

  static Future<T?> show<T>({
    required BuildContext context,
    required List<Widget> children,
    Widget? header,
    List<Widget>? headerActions,
    double initialChildSize = 0.6,
    double maxChildSize = 0.9,
    double minChildSize = 0.4,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StaggeredBottomSheet(
        children: children,
        header: header,
        headerActions: headerActions,
        initialChildSize: initialChildSize,
        maxChildSize: maxChildSize,
        minChildSize: minChildSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      maxChildSize: maxChildSize,
      minChildSize: minChildSize,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: dragHandleColor ?? AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (header != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: header!),
                    if (headerActions != null) ...headerActions!,
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (int i = 0; i < children.length; i++)
                    children[i]
                        .animate()
                        .fadeIn(duration: 300.ms, delay: (100 + i * 80).ms)
                        .slideY(begin: 0.2, end: 0, duration: 300.ms, delay: (100 + i * 80).ms, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaggeredList extends StatelessWidget {
  const StaggeredList({
    super.key,
    required this.children,
    this.padding,
    this.itemDelay = 60,
    this.fadeDuration = 300,
    this.slideOffset = 0.15,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final int itemDelay;
  final int fadeDuration;
  final double slideOffset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        for (int i = 0; i < children.length; i++)
          children[i]
              .animate()
              .fadeIn(duration: fadeDuration.ms, delay: (i * itemDelay).ms)
              .slideY(
                begin: slideOffset,
                end: 0,
                duration: fadeDuration.ms,
                delay: (i * itemDelay).ms,
                curve: Curves.easeOutCubic,
              ),
      ],
    );
  }
}

class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.itemDelay = 60,
    this.fadeDuration = 300,
    this.slideOffset = 0.15,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final int itemDelay;
  final int fadeDuration;
  final double slideOffset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (int i = 0; i < children.length; i++)
          children[i]
              .animate()
              .fadeIn(duration: fadeDuration.ms, delay: (i * itemDelay).ms)
              .slideY(
                begin: slideOffset,
                end: 0,
                duration: fadeDuration.ms,
                delay: (i * itemDelay).ms,
                curve: Curves.easeOutCubic,
              ),
      ],
    );
  }
}