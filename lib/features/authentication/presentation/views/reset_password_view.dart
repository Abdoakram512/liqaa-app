import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

/// Interactive Reset Password view with privacy eye-covering.
class ResetPasswordView extends StatefulWidget {
  final String email;

  const ResetPasswordView({super.key, required this.email});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  late YasserController _yasserController;
  late ConfettiController _confettiController;
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _visiblePasswords = <FocusNode, bool>{};

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    _passwordFocusNode.addListener(_handlePasswordFocus);
    _confirmPasswordFocusNode.addListener(_handlePasswordFocus);
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _yasserController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handlePasswordFocus() {
    if (_passwordFocusNode.hasFocus || _confirmPasswordFocusNode.hasFocus) {
      final field = _passwordFocusNode.hasFocus
          ? _passwordFocusNode
          : _confirmPasswordFocusNode;
      if (_visiblePasswords[field] == true) {
        _yasserController.peek();
      } else {
        _yasserController.coverEyes();
      }
    } else {
      _yasserController.uncoverEyes();
    }
  }

  void _handleVisibility(FocusNode field, bool visible) {
    _visiblePasswords[field] = visible;
    if (field.hasFocus) _handlePasswordFocus();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      _yasserController.reactToValidation(false);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _yasserController.reactToValidation(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('كلمتا المرور غير متطابقتين'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<AuthCubit>().resetPassword(
          email: widget.email,
          newPassword: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthPasswordResetSuccess) {
          FocusScope.of(context).unfocus();
          _confettiController.play();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _yasserController.celebrate();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Future.delayed(const Duration(milliseconds: 1500), () {
            if (context.mounted) {
              context.go(AppRoutes.login);
            }
          });
        } else if (state is AuthFailure) {
          _yasserController.reactToValidation(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          body: ConfettiCelebrationOverlay(
            confettiController: _confettiController,
            child: PhonologicalBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
                            ),
                            const Spacer(),
                            Text(
                              'كلمة مرور جديدة',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),

                        SizedBox(height: 12.h),

                        YasserCharacter(
                          controller: _yasserController,
                          width: 200.w,
                          height: 230.h,
                          heroTag: 'yasser_reset_character',
                        ).animate().fadeIn(duration: 500.ms),

                        SizedBox(height: 16.h),

                        YasserTextField(
                          label: 'كلمة المرور الجديدة',
                          hint: '6 خانات على الأقل',
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          isPassword: true,
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          onPasswordVisibilityChanged: (visible) =>
                              _handleVisibility(_passwordFocusNode, visible),
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'يجب أن تتكون من 6 خانات على الأقل';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 16.h),

                        YasserTextField(
                          label: 'تأكيد كلمة المرور الجديدة',
                          hint: 'أعد كتابة كلمة المرور',
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon: const Icon(Icons.lock_outline),
                          onPasswordVisibilityChanged: (visible) =>
                              _handleVisibility(_confirmPasswordFocusNode, visible),
                          onFieldSubmitted: _submit,
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'كلمتا المرور غير متطابقتين';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 28.h),

                        PrimaryButton(
                          label: 'حفظ كلمة المرور والدخول 🔒',
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
