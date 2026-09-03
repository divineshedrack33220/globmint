import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/radius_tokens.dart';
import '../theme/theme_extensions.dart';

class PinInput extends StatefulWidget {
  const PinInput({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.errorText,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool autofocus;

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late FocusNode _keyboardFocusNode;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _keyboardFocusNode = FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  String get _pin => _controllers.map((c) => c.text).join();

  void _onDigit(int index, String value) {
    if (value.length == 1 && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    widget.onChanged?.call(_pin);
    if (_pin.length == widget.length) {
      widget.onCompleted?.call(_pin);
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      for (int i = 0; i < widget.length; i++) {
        if (event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty &&
            i > 0) {
          _controllers[i - 1].clear();
          _focusNodes[i - 1].requestFocus();
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _onKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              return Container(
                width: 48,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  obscureText: true,
                  obscuringCharacter: '•',
                  style: context.typography.headline.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.destructive,
                        width: 1.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.destructive,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (v) => _onDigit(index, v),
                ),
              );
            }),
          ),
          if (widget.errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.errorText!,
              style: context.typography.bodySmall.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}