import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lightweight shimmer sweep for loading placeholders. Wraps a child in a
/// moving diagonal-hill gradient so skeleton shapes read as "still loading"
/// instead of static grey blocks. No external dependency.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * 2.0 - 1.0; // -1 .. 1 sweep position
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(t - 1.0, -1.0),
            end: Alignment(t + 1.0, 1.0),
            colors: const [
              Colors.transparent,
              Colors.white38,
              Colors.transparent,
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A single shimmering rounded placeholder block.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.color,
  });

  final double? width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton of a transaction row (leading icon box + two text lines + right
/// column), used while the activity feeds are still loading.
class TransactionTileSkeleton extends StatelessWidget {
  const TransactionTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const ShimmerBox(width: 44, height: 44, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 120, height: 12, radius: 6),
                SizedBox(height: 8),
                ShimmerBox(width: 180, height: 10, radius: 5),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              ShimmerBox(width: 72, height: 12, radius: 6),
              SizedBox(height: 8),
              ShimmerBox(width: 40, height: 10, radius: 5),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton list that mirrors the home "Recent Activity" / savings activity
/// card shape during the first load.
class TransactionListSkeleton extends StatelessWidget {
  const TransactionListSkeleton({super.key, this.tiles = 5});

  final int tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: List.generate(tiles, (index) {
          return Column(
            children: [
              const TransactionTileSkeleton(),
              if (index < tiles - 1)
                const Divider(height: 1, indent: 68, color: AppColors.divider),
            ],
          );
        }),
      ),
    );
  }
}
