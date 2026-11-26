import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/yasser_design_tokens.dart';

/// Tactile squircle 4-digit OTP input component supporting paste, backspace
/// traversal, LTR digit ordering inside RTL Arabic layouts, and error states.
class YasserOtpField extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;

  const YasserOtpField({
    super.key,
    this.length = 4,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
  });

  @override
  State<YasserOtpField> createState() => YasserOtpFieldState();
}

class YasserOtpFieldState extends State<YasserOtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  String get currentCode => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      return node;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
    setState(() {});
  }

  void _handleChanged(int index, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // Handle multi-digit paste cleanly across cells
    if (digits.length > 1) {
      for (int i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final nextIdx = digits.length >= widget.length
          ? widget.length - 1
          : digits.length;
      if (digits.length >= widget.length) {
        _focusNodes[nextIdx].unfocus();
      } else {
        _focusNodes[nextIdx].requestFocus();
      }
      _notify();
      return;
    }

    _controllers[index].text = digits;
    _controllers[index].selection = TextSelection.collapsed(
      offset: digits.length,
    );

    if (digits.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    _notify();
  }

  void _notify() {
    setState(() {});
    final code = currentCode;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (index) {
          final bool focused = _focusNodes[index].hasFocus;
          final bool filled = _controllers[index].text.isNotEmpty;

          final Color borderColor = widget.hasError
              ? AppColors.error
              : (focused
                    ? AppColors.primary
                    : (filled ? AppColors.primaryDark : AppColors.borderInput));
          final Color lipColor = widget.hasError
              ? AppColors.errorDark.withValues(alpha: 0.45)
              : (focused ? AppColors.primaryDark : AppColors.borderStrong);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: AnimatedContainer(
              duration: YasserMotion.fieldFocus,
              width: 62.w.clamp(52.0, 68.0),
              height: 68.h.clamp(58.0, 74.0),
              decoration: ShapeDecoration(
                color: focused ? AppColors.surface : AppColors.surfaceInput,
                shape: YasserShapes.squircle(
                  AppSpacing.radiusM,
                  side: BorderSide(
                    color: borderColor,
                    width: focused ? 2.4 : 1.6,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: lipColor.withValues(alpha: focused ? 0.35 : 0.25),
                    blurRadius: focused ? 12 : 0,
                    offset: const Offset(0, 3.5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: index == widget.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                style: AppTextStyles.displaySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => _handleChanged(index, v),
              ),
            ),
          );
        }),
      ),
    );
  }
}
