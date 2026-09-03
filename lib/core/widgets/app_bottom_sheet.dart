import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/radius_tokens.dart';

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.isScrollControlled = true,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 32),
  });

  final Widget child;
  final String? title;
  final bool isScrollControlled;
  final EdgeInsetsGeometry padding;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 0, 24, 32),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        title: title,
        padding: padding,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadiusAccess.xlTop,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Flexible(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class AppRadiusAccess {
  static const BorderRadius xlTop = BorderRadius.vertical(
    top: Radius.circular(AppRadius.xl),
  );
}
