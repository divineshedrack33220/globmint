import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Currencies a user can choose to view their balance in.
enum DisplayCurrency {
  ngn('NGN', '₦', '🇳🇬'),
  usd('USD', r'$', '🇺🇸'),
  usdc('USDC', '', '◉');

  const DisplayCurrency(this.code, this.symbol, this.flag);

  final String code;
  final String symbol;
  final String flag;

  static DisplayCurrency fromCode(String? code) {
    if (code == null) return ngn;
    return DisplayCurrency.values.firstWhere(
      (c) => c.code == code.toUpperCase(),
      orElse: () => ngn,
    );
  }
}

/// Compact currency flag + code chip. Tapping opens a dropdown listing all
/// supported display currencies; selecting one reports back via [onChanged].
class CurrencyFlagSelector extends StatelessWidget {
  const CurrencyFlagSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final DisplayCurrency current;
  final ValueChanged<DisplayCurrency> onChanged;

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Display currency',
              style: context.typography.title,
            ),
            const SizedBox(height: 8),
            for (final currency in DisplayCurrency.values) ...[
              ListTile(
                leading: Text(
                  currency.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  currency.code,
                  style: context.typography.labelLarge,
                ),
                subtitle: currency.symbol.isEmpty
                    ? null
                    : Text(
                        '${currency.symbol}${currency.code == 'USD' ? ' Dollar' : ' Naira'}',
                        style: context.typography.bodySmall,
                      ),
                trailing: currency == current
                    ? const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (currency != current) onChanged(currency);
                },
              ),
              if (currency != DisplayCurrency.values.last)
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.divider,
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primarySubtle,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              current.code,
              style: context.typography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}