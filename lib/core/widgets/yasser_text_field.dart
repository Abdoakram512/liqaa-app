import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/yasser_design_tokens.dart';

/// Semantic input variants tailored to Yasser's child, parent, and specialist flows.
enum YasserFieldVariant {
  standard,
  name,
  email,
  phone,
  password,
  confirmPassword,
  search,
  multilineNotes,
  specialistCase,
}

/// Redesigned tactile squircle text input system for LIQAA / Yasser.
///
/// Features:
/// - Soft layered squircle container with subtle bottom lip & animated focus ring
/// - Preserves native [TextFormField] editing, paste, selection, autofill, and [Form] validation
/// - Automatic LTR directionality for emails, phones, and passwords inside Arabic RTL layouts
/// - Smooth helper/error feedback without resizing or shifting the input box itself
/// - Full support for empty, filled, focused, error, disabled, read-only, and validation-success states
class YasserTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final TextEditingController? controller;
  final YasserFieldVariant variant;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onFocusChanged;
  final ValueChanged<bool>? onPasswordVisibilityChanged;
  final VoidCallback? onFieldSubmitted;
  final VoidCallback? onClearSearch;
  final FocusNode? focusNode;
  final bool enabled;
  final bool readOnly;
  final bool showValidationSuccess;
  final int? maxLines;
  final int? minLines;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextDirection? textDirection;

  const YasserTextField({
    super.key,
    this.label = '',
    this.hint,
    this.helperText,
    this.controller,
    this.variant = YasserFieldVariant.standard,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onFocusChanged,
    this.onPasswordVisibilityChanged,
    this.onFieldSubmitted,
    this.onClearSearch,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.showValidationSuccess = false,
    this.maxLines,
    this.minLines,
    this.autofillHints,
    this.inputFormatters,
    this.textDirection,
  });

  @override
  State<YasserTextField> createState() => _YasserTextFieldState();
}

class _YasserTextFieldState extends State<YasserTextField> {
  late FocusNode _focusNode;
  TextEditingController? _internalController;
  bool _isObscured = true;
  bool _hasFocus = false;
  String? _errorText;
  bool _hasText = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  bool get _isPasswordField =>
      widget.isPassword ||
      widget.variant == YasserFieldVariant.password ||
      widget.variant == YasserFieldVariant.confirmPassword;

  bool get _isMultiline =>
      widget.variant == YasserFieldVariant.multilineNotes ||
      (widget.maxLines != null && widget.maxLines! > 1);

  @override
  void initState() {
    super.initState();
    _isObscured = _isPasswordField;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _effectiveController.addListener(_handleTextUpdate);
    _hasText = _effectiveController.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant YasserTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleTextUpdate);
      _effectiveController.addListener(_handleTextUpdate);
      _hasText = _effectiveController.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _effectiveController.removeListener(_handleTextUpdate);
    _internalController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  void _handleTextUpdate() {
    if (!mounted) return;
    final nonEmpty = _effectiveController.text.trim().isNotEmpty;
    if (nonEmpty != _hasText || (_errorText != null && nonEmpty)) {
      setState(() {
        _hasText = nonEmpty;
        if (_errorText != null) {
          _errorText = widget.validator?.call(_effectiveController.text);
        }
      });
    }
  }

  void _toggleObscure() {
    setState(() {
      _isObscured = !_isObscured;
    });
    widget.onPasswordVisibilityChanged?.call(!_isObscured);
  }

  TextInputType get _resolvedKeyboardType {
    if (widget.keyboardType != null) return widget.keyboardType!;
    return switch (widget.variant) {
      YasserFieldVariant.email => TextInputType.emailAddress,
      YasserFieldVariant.phone => TextInputType.phone,
      YasserFieldVariant.multilineNotes => TextInputType.multiline,
      YasserFieldVariant.name => TextInputType.name,
      _ => TextInputType.text,
    };
  }

  Iterable<String>? get _resolvedAutofillHints {
    if (!widget.enabled || widget.readOnly) return null;
    if (widget.autofillHints != null) return widget.autofillHints;
    return switch (widget.variant) {
      YasserFieldVariant.name => const [AutofillHints.name],
      YasserFieldVariant.email => const [AutofillHints.email],
      YasserFieldVariant.phone => const [AutofillHints.telephoneNumber],
      YasserFieldVariant.password => const [AutofillHints.password],
      YasserFieldVariant.confirmPassword => const [AutofillHints.newPassword],
      _ => _isPasswordField ? const [AutofillHints.password] : null,
    };
  }

  TextDirection _resolveInputDirection(BuildContext context) {
    if (widget.textDirection != null) return widget.textDirection!;
    if (_isPasswordField ||
        widget.variant == YasserFieldVariant.email ||
        widget.variant == YasserFieldVariant.phone ||
        widget.keyboardType == TextInputType.emailAddress ||
        widget.keyboardType == TextInputType.phone) {
      return TextDirection.ltr;
    }
    return Directionality.of(context);
  }

  Widget? _buildDefaultPrefixIcon() {
    if (widget.prefixIcon != null) return widget.prefixIcon;
    return switch (widget.variant) {
      YasserFieldVariant.name => const Icon(Icons.person_rounded),
      YasserFieldVariant.email => const Icon(Icons.alternate_email_rounded),
      YasserFieldVariant.phone => const Icon(Icons.phone_iphone_rounded),
      YasserFieldVariant.password => const Icon(Icons.lock_rounded),
      YasserFieldVariant.confirmPassword => const Icon(
        Icons.verified_user_rounded,
      ),
      YasserFieldVariant.search => const Icon(Icons.search_rounded),
      YasserFieldVariant.multilineNotes => const Icon(Icons.notes_rounded),
      YasserFieldVariant.specialistCase => const Icon(
        Icons.assignment_ind_rounded,
      ),
      YasserFieldVariant.standard => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = _errorText != null && _errorText!.isNotEmpty;
    final bool isSuccess =
        !hasError &&
        widget.showValidationSuccess &&
        _hasText &&
        (widget.validator == null ||
            widget.validator!(_effectiveController.text) == null);

    final Color activeAccent = !widget.enabled
        ? AppColors.disabledText
        : hasError
        ? AppColors.error
        : isSuccess
        ? AppColors.success
        : (_hasFocus ? AppColors.primary : AppColors.textPrimary);

    final Color borderColor = !widget.enabled
        ? AppColors.disabledLip
        : hasError
        ? AppColors.error
        : isSuccess
        ? AppColors.success
        : (_hasFocus
              ? AppColors.primary
              : (_hasText ? AppColors.borderStrong : AppColors.borderInput));

    final Color surfaceColor = !widget.enabled
        ? AppColors.disabledSurface.withValues(alpha: 0.65)
        : widget.readOnly
        ? AppColors.surfaceSubtle
        : (_hasFocus ? AppColors.surface : AppColors.surfaceInput);

    final Widget? resolvedPrefix = _buildDefaultPrefixIcon();
    final TextDirection inputDirection = _resolveInputDirection(context);

    Widget? resolvedSuffix = widget.suffixIcon;
    if (_isPasswordField) {
      resolvedSuffix = IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Icon(
            _isObscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            key: ValueKey<bool>(_isObscured),
            color: _isObscured
                ? AppColors.textSecondary
                : AppColors.primaryDark,
            size: 21,
          ),
        ),
        onPressed: widget.enabled ? _toggleObscure : null,
        tooltip: _isObscured ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      );
    } else if (widget.variant == YasserFieldVariant.search && _hasText) {
      resolvedSuffix = IconButton(
        icon: const Icon(
          Icons.close_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        tooltip: 'مسح البحث',
        onPressed: () {
          _effectiveController.clear();
          widget.onChanged?.call('');
          widget.onClearSearch?.call();
        },
      );
    } else if (isSuccess && resolvedSuffix == null) {
      resolvedSuffix = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 20,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: hasError
                          ? AppColors.errorDark
                          : (_hasFocus
                                ? AppColors.primaryDeep
                                : AppColors.textPrimary),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.readOnly) ...[
                  SizedBox(width: 6.w),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'للقراءة فقط',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Tactile Squircle Input Container (Fixed Stable Geometry)
        AnimatedContainer(
          duration: YasserMotion.effective(context, YasserMotion.fieldFocus),
          curve: YasserMotion.calmCurve,
          constraints: BoxConstraints(
            minHeight: _isMultiline ? 108.0 : AppSpacing.inputMinHeight,
          ),
          decoration: ShapeDecoration(
            color: surfaceColor,
            shape: YasserShapes.squircle(
              AppSpacing.radiusM + 2,
              side: BorderSide(
                color: borderColor,
                width: (_hasFocus || hasError) ? 2.2 : 1.5,
              ),
            ),
            shadows: [
              BoxShadow(
                color: hasError
                    ? AppColors.error.withValues(alpha: 0.14)
                    : (_hasFocus
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : AppColors.borderStrong.withValues(alpha: 0.35)),
                blurRadius: _hasFocus ? 14 : 0,
                spreadRadius: _hasFocus ? 1 : 0,
                offset: Offset(0, _hasFocus ? 4 : 2.5),
              ),
            ],
          ),
          alignment: _isMultiline ? Alignment.topCenter : Alignment.center,
          child: TextFormField(
            controller: _effectiveController,
            focusNode: _focusNode,
            obscureText: _isPasswordField && _isObscured,
            keyboardType: _resolvedKeyboardType,
            textInputAction: _isMultiline
                ? TextInputAction.newline
                : widget.textInputAction,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLines: _isPasswordField ? 1 : (widget.maxLines ?? 1),
            minLines: _isPasswordField ? 1 : widget.minLines,
            autofillHints: _resolvedAutofillHints,
            inputFormatters: widget.inputFormatters,
            textDirection: inputDirection,
            cursorColor: AppColors.primaryDark,
            cursorRadius: const Radius.circular(4),
            style: AppTextStyles.bodyLarge.copyWith(
              color: widget.enabled
                  ? AppColors.textPrimary
                  : AppColors.disabledText,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintTextDirection: Directionality.of(context),
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: resolvedPrefix != null
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 12,
                        end: 8,
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: ShapeDecoration(
                          color: (_hasFocus || hasError || isSuccess)
                              ? activeAccent.withValues(alpha: 0.12)
                              : AppColors.primaryUltraLight,
                          shape: YasserShapes.squircle(11),
                        ),
                        alignment: Alignment.center,
                        child: IconTheme(
                          data: IconThemeData(
                            color: _hasFocus || hasError || isSuccess
                                ? activeAccent
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          child: resolvedPrefix,
                        ),
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 54,
                minHeight: 44,
              ),
              suffixIcon: resolvedSuffix,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: _isMultiline ? 16 : 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              // Hide built-in border-warping error label; rendered smoothly below
              errorStyle: const TextStyle(
                fontSize: 0,
                height: 0.01,
                color: Colors.transparent,
              ),
            ),
            validator: (value) {
              final err = widget.validator?.call(value);
              if (err != _errorText) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _errorText != err) {
                    setState(() => _errorText = err);
                  }
                });
              }
              return err;
            },
            onChanged: (value) {
              if (_errorText != null) {
                final nextErr = widget.validator?.call(value);
                if (nextErr != _errorText) {
                  setState(() => _errorText = nextErr);
                }
              }
              widget.onChanged?.call(value);
            },
            onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
          ),
        ),

        // Reserved smooth validation / helper feedback zone
        AnimatedSize(
          duration: YasserMotion.effective(
            context,
            const Duration(milliseconds: 180),
          ),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6, left: 6),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.errorDark,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.errorDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : (widget.helperText != null && widget.helperText!.isNotEmpty)
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6, left: 6),
                  child: Text(
                    widget.helperText!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
