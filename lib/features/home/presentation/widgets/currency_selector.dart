import 'package:flutter/material.dart';

/// Enum of supported currencies in the app.
enum AppCurrency { ngn, usd, usdt }

extension AppCurrencyExtension on AppCurrency {
  String get label {
    switch (this) {
      case AppCurrency.ngn:
        return 'NGN';
      case AppCurrency.usd:
        return 'USD';
      case AppCurrency.usdt:
        return 'USDT';
    }
  }

  String get flagEmoji {
    switch (this) {
      case AppCurrency.ngn:
        return '🇳🇬';
      case AppCurrency.usd:
        return '🇺🇸';
      case AppCurrency.usdt:
        return '🇺🇸';
    }
  }

  String get formatSymbol {
    switch (this) {
      case AppCurrency.ngn:
        return '₦';
      case AppCurrency.usd:
        return '';
      case AppCurrency.usdt:
        return 'USDT';
    }
  }
}

/// Currency dropdown button shown in the app bar.
class CurrencyDropdownButton extends ConsumerWidget {
  const CurrencyDropdownButton({
    super.key,
    required this.onChanged,
    this.value = AppCurrency.ngn,
  });

  final ValueChanged<AppCurrency> onChanged;
  final AppCurrency value;

  /// Builds the menu items for the dropdown.
  static List<DropdownMenuItem<AppCurrency>> _items() => [
        const DropdownMenuItem<AppCurrency>(
          value: AppCurrency.ngn,
          child: Row(
            children: [
              Icon(Icons Monetization),
              SizedBox(width: 6),
              Text('NGN'),
            ],
          ),
        ),
        const DropdownMenuItem<AppCurrency>(
          value: AppCurrency.usd,
          child: Row(
            children: [
              Icon(Icons Dollars),
              SizedBox(width: 6),
              Text('USD'),
            ],
          ),
        ),
        const DropdownMenuItem<AppCurrency>(
          value: AppCurrency.usdt,
          child: Row(
            children: [
              Icon(Icons Monetary),
              SizedBox(width: 6),
              Text('USDT'),
            ],
          ),
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the saved preference from the user profile / shared prefs.
    // For now, fall back to the app default (NGN).
    final selected = ref.watch(currencyPreferenceProvider);
    final isSelected = selected == value;

    return Tooltip(
      message: 'Change currency',
      child: DropdownButton<AppCurrency>(
        value: isSelected ? value : AppCurrency.ngn,
        onChanged: (AppCurrency? newValue) {
          if (newValue != null) {
            onChanged(newValue);
            ref.read(currencyPreferenceProvider.notifier).state = newValue;
          }
        },
        icon: const Icon(Icons.arrow_drop_down),
        items: _items(),
        underline: const SizedBox.shrink(),
      ),
    );
  }
}

/// Provides the user's selected currency preference.
final currencyPreferenceProvider = StateProvider<AppCurrency>((ref) => AppCurrency.ngn);
