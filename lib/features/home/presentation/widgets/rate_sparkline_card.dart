import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer.dart';
import '../../../../shared/services/rate_sampler.dart';

/// USDC/NGN rate card with a trend sparkline. History accumulates on-device
/// (one sample per hour, latest 30); until enough samples exist the card
/// shows the live rate with a "building history" note instead of a chart.
class RateSparklineCard extends StatefulWidget {
  const RateSparklineCard({super.key, required this.rate});

  final double rate;

  @override
  State<RateSparklineCard> createState() => _RateSparklineCardState();
}

class _RateSparklineCardState extends State<RateSparklineCard> {
  List<double> _points = const [];

  @override
  void initState() {
    super.initState();
    _sample();
  }

  @override
  void didUpdateWidget(RateSparklineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate != widget.rate) _sample();
  }

  Future<void> _sample() async {
    final sampler = await RateSampler.load();
    final points = sampler.record(widget.rate);
    if (mounted) setState(() => _points = points);
  }

  @override
  Widget build(BuildContext context) {
    // Rate has not loaded yet: show a shimmer skeleton in place of data.
    if (widget.rate <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 120, height: 12, radius: 6),
            SizedBox(height: 18),
            ShimmerBox(width: double.infinity, height: 48, radius: 8),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('USDC / NGN rate', style: context.typography.labelMedium),
              Text(
                CurrencyFormatter.ngn(widget.rate),
                style: context.typography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: _points.length < 2
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Rate history building… check back later',
                      style: context.typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : CustomPaint(painter: _SparklinePainter(_points)),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points);

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final span = (max - min) == 0 ? 1.0 : (max - min);
    // Pad flat lines to mid-height so a stable rate still draws visibly.
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y =
          size.height - 4 - ((points[i] - min) / span) * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final linePaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Last-sample dot.
    final lastX = size.width;
    final lastY =
        size.height - 4 - ((points.last - min) / span) * (size.height - 8);
    canvas.drawCircle(
      Offset(lastX - 2, lastY),
      3,
      Paint()..color = const Color(0xFF2E7D32),
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points;
}
