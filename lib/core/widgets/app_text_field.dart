import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textInputAction,
    this.maxLines = 1,
    this.errorText,
    this.contentPadding,
  });

  final String? label;
  final String? hint;
  final Widget? prefix;
  final Widget? suffix;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final int maxLines;
  final String? errorText;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.typography.labelMedium,
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          textInputAction: textInputAction,
          maxLines: maxLines,
          style: context.typography.bodyLarge.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
            errorText: errorText,
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class AmountTextField extends StatelessWidget {
  const AmountTextField({
    super.key,
    this.controller,
    this.label,
    this.hint = '0.00',
    this.prefixText = '₦',
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String hint;
  final String prefixText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: context.typography.labelMedium),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
          ],
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          style: context.typography.amountMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixStyle: context.typography.amountMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            hintStyle: context.typography.amountMedium.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}

class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint ?? 'Enter your password',
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      validator: widget.validator,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      suffix: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.textTertiary,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

class SearchTextField extends StatelessWidget {
  const SearchTextField({
    super.key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hint: hint,
      onChanged: onChanged,
      prefix: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Icon(Icons.search, color: AppColors.textTertiary, size: 20),
      ),
    );
  }
}
