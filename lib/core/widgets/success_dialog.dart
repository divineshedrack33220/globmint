import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';
import 'app_button.dart';

enum SuccessDialogType { success, conversion, transfer, warning }

class SuccessDialog extends StatefulWidget {
  const SuccessDialog({
    super.key,
    required this.type,
    required this.title,
    required this.amount,
    this.subtitle,
    this.buttonText = 'Done',
    this.onPressed,
    this.autoDismiss = false,
  });

  final SuccessDialogType type;
  final String title;
  final String amount;
  final String? subtitle;
  final String buttonText;
  final VoidCallback? onPressed;
  final bool autoDismiss;

  static Future<void> show({
    required BuildContext context,
    required SuccessDialogType type,
    required String title,
    required String amount,
    String? subtitle,
    String buttonText = 'Done',
    VoidCallback? onPressed,
    bool autoDismiss = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !autoDismiss,
      barrierColor: AppColors.overlay,
      builder: (_) => SuccessDialog(
        type: type,
        title: title,
        amount: amount,
        subtitle: subtitle,
        buttonText: buttonText,
        onPressed: onPressed,
        autoDismiss: autoDismiss,
      ),
    );
  }

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );

    _controller.forward();

    if (widget.autoDismiss) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (iconData, iconColor, bgColor) = switch (widget.type) {
      SuccessDialogType.success => (Icons.check, AppColors.success, AppColors.successMuted),
      SuccessDialogType.conversion => (Icons.currency_exchange, AppColors.primary, AppColors.primarySubtle),
      SuccessDialogType.transfer => (Icons.send, AppColors.info, AppColors.infoMuted),
      SuccessDialogType.warning => (Icons.warning_amber, AppColors.warning, AppColors.warningMuted),
    };

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CheckmarkPainter(
                        progress: _checkAnimation.value,
                        color: iconColor,
                        strokeWidth: 4,
                      ),
                      size: const Size(80, 80),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: context.typography.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.amount,
              style: context.typography.amountHeroHighlight.copyWith(
                color: iconColor,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: context.typography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              text: widget.buttonText,
              onPressed: () {
                Navigator.of(context).pop();
                widget.onPressed?.call();
              },
              isExpanded: true,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
      begin: const Offset(0.9, 0.9),
      end: const Offset(1.0, 1.0),
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.45;

    // Draw circle background stroke
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, circlePaint);

    // Draw checkmark
    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const startX = 0.25;
    const midX = 0.45;
    const endX = 0.75;
    const startY = 0.5;
    const midY = 0.7;
    const endY = 0.3;

    final animatedMid = 0.5 + (midY - 0.5) * progress;
    final animatedEnd = 0.5 + (endY - 0.5) * progress;

    path.moveTo(size.width * startX, size.height * startY);
    path.lineTo(size.width * midX, size.height * animatedMid);
    path.lineTo(size.width * endX, size.height * animatedEnd);

    final pathMetric = path.computeMetrics().first;
    final extractPath = pathMetric.extractPath(0, pathMetric.length * progress);

    canvas.drawPath(extractPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}