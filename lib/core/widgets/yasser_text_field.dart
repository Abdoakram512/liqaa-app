import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Premium, child-and-parent-friendly interactive text input field.
///
/// Dispatches focus and visibility events directly to character hooks
/// without ever passing or exposing raw credentials.
class YasserTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onFocusChanged;
  final ValueChanged<bool>? onPasswordVisibilityChanged;
  final VoidCallback? onFieldSubmitted;
  final FocusNode? focusNode;
  final bool enabled;

  const YasserTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.onFocusChanged,
    this.onPasswordVisibilityChanged,
    this.onFieldSubmitted,
    this.focusNode,
    this.enabled = true,
  });

  @override
  State<YasserTextField> createState() => _YasserTextFieldState();
}

class _YasserTextFieldState extends State<YasserTextField> {
  late FocusNode _focusNode;
  bool _isObscured = true;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.isPassword;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
      widget.onFocusChanged?.call(_focusNode.hasFocus);
    }
  }

  void _toggleObscure() {
    setState(() {
      _isObscured = !_isObscured;
    });
    widget.onPasswordVisibilityChanged?.call(!_isObscured);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field Label
        Text(
          widget.label,
          style: AppTextStyles.labelLarge.copyWith(
            color: _hasFocus ? AppColors.primary : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Animated Input Container
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _hasFocus
                    ? AppColors.primary.withOpacity(0.18)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _hasFocus ? 16 : 8,
                spreadRadius: _hasFocus ? 2 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.isPassword && _isObscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            enabled: widget.enabled,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
              prefixIcon: widget.prefixIcon != null
                  ? IconTheme(
                      data: IconThemeData(
                        color: _hasFocus
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      child: widget.prefixIcon!,
                    )
                  : null,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _isObscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _isObscured
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                      onPressed: _toggleObscure,
                      tooltip: _isObscured ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2.2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.8,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 2.2,
                ),
              ),
            ),
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
          ),
        ),
      ],
    );
  }
}
