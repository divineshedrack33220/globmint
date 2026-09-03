import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor ?? AppColors.skeletonBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).shimmer(
      duration: 1500.ms,
      color: highlightColor ?? AppColors.skeletonShimmer,
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(width: 44, height: 44, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 120, height: 16, borderRadius: 4),
                    const SizedBox(height: 8),
                    const SkeletonLoader(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonBalanceCard extends StatelessWidget {
  const SkeletonBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 140, height: 12, borderRadius: 4),
          const SizedBox(height: 12),
          const SkeletonLoader(width: 180, height: 42, borderRadius: 8),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 120, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

class SkeletonActionRow extends StatelessWidget {
  const SkeletonActionRow({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonLoader(width: 100, height: 16, borderRadius: 4),
        const SizedBox(height: 16),
        Row(
          children: List.generate(count, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == count - 1 ? 0 : 12),
                child: const SkeletonLoader(height: 80, borderRadius: 16),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class SkeletonTransactionList extends StatelessWidget {
  const SkeletonTransactionList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: 68,
        color: AppColors.divider,
      ),
      itemBuilder: (_, _) => const SkeletonTransactionTile(),
    );
  }
}

class SkeletonTransactionTile extends StatelessWidget {
  const SkeletonTransactionTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SkeletonLoader(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 120, height: 16, borderRadius: 4),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 160, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SkeletonLoader(width: 80, height: 16, borderRadius: 4),
              const SizedBox(height: 4),
              const SkeletonLoader(width: 60, height: 10, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonSettingsSection extends StatelessWidget {
  const SkeletonSettingsSection({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonLoader(width: 80, height: 12, borderRadius: 4),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: List.generate(itemCount, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const SkeletonLoader(width: 20, height: 20, borderRadius: 6),
                    const SizedBox(width: 12),
                    Expanded(child: SkeletonLoader(height: 16, borderRadius: 4)),
                    const SkeletonLoader(width: 20, height: 20, borderRadius: 6),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}