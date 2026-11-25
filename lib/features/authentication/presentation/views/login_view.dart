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

/// Premium Interactive Login Screen where Yasser actively participates
/// and reacts to form interactions, password privacy, and authentication states.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late YasserController _yasserController;
  late ConfettiController _confettiController;
  final _formKey = GlobalKey<FormState>();

  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();

  final _identityFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _rememberMe = true;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    _identityController.addListener(_updateIdentityGaze);
    _identityFocusNode.addListener(_handleIdentityFocus);
    _passwordFocusNode.addListener(_handlePasswordFocus);
  }

  @override
  void dispose() {
    _identityController.removeListener(_updateIdentityGaze);
    _identityFocusNode.removeListener(_handleIdentityFocus);
    _passwordFocusNode.removeListener(_handlePasswordFocus);
    _identityFocusNode.dispose();
    _passwordFocusNode.dispose();
    _identityController.dispose();
    _passwordController.dispose();
    _yasserController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleIdentityFocus() {
    if (_identityFocusNode.hasFocus) {
      _updateIdentityGaze();
    } else if (!_passwordFocusNode.hasFocus) {
      _yasserController.returnToIdle();
    }
  }

  void _handlePasswordFocus() {
    if (_passwordFocusNode.hasFocus) {
      _handlePasswordVisibility(_passwordVisible);
    } else {
      _yasserController.uncoverEyes();
      if (_identityFocusNode.hasFocus) {
        _updateIdentityGaze();
      }
    }
  }

  void _updateIdentityGaze() {
    if (!_identityFocusNode.hasFocus) return;
    _yasserController.followCaret(
      _identityController.selection.extentOffset,
      textLength: _identityController.text.length,
      rightToLeft: Directionality.of(context) == TextDirection.rtl,
    );
  }

  void _handlePasswordVisibility(bool isVisible) {
    _passwordVisible = isVisible;
    if (!_passwordFocusNode.hasFocus) return;
    if (isVisible) {
      _yasserController.peek();
    } else {
      _yasserController.coverEyes();
    }
  }

  void _submitLogin() {
    if (!_formKey.currentState!.validate()) {
      _yasserController.reactToValidation(false);
      return;
    }

    context.read<AuthCubit>().login(
          identity: _identityController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          Future.delayed(const Duration(milliseconds: 1400), () {
            if (context.mounted) {
              context.go(AppRoutes.game);
            }
          });
        } else if (state is AuthFailure) {
          _yasserController.reactToValidation(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                        // Back navigation bar
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
                              tooltip: 'رجوع',
                            ),
                            const Spacer(),
                            Text(
                              'تسجيل الدخول',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),

                        SizedBox(height: 8.h),

                        // Living Yasser Character responding to form
                        YasserCharacter(
                          controller: _yasserController,
                          width: 220.w,
                          height: 250.h,
                          heroTag: 'yasser_login_character',
                        ).animate().fadeIn(duration: 500.ms),

                        SizedBox(height: 12.h),

                        // Identity Input (Username or Email)
                        YasserTextField(
                          label: 'اسم البطل أو البريد الإلكتروني',
                          hint: 'مثال: أحمد أو ahmed@liqaa.com',
                          controller: _identityController,
                          focusNode: _identityFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.person_pin_rounded),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال اسم المستخدم أو البريد الإلكتروني';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                        SizedBox(height: 16.h),

                        // Password Field with Eye-Covering Behavior
                        YasserTextField(
                          label: 'كلمة المرور السرية',
                          hint: 'أدخل كلمة المرور (6 خانات على الأقل)',
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon: const Icon(Icons.lock_rounded),
                          onPasswordVisibilityChanged: _handlePasswordVisibility,
                          onFieldSubmitted: _submitLogin,
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'كلمة المرور يجب أن تتكون من 6 خانات على الأقل';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                        SizedBox(height: 10.h),

                        // Remember Me & Forgot Password Row
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              onChanged: (v) => setState(() => _rememberMe = v ?? true),
                            ),
                            Text(
                              'تذكرني',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push(AppRoutes.forgotPassword),
                              child: Text(
                                'نسيت كلمة المرور؟',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16.h),

                        // Login Action Button
                        PrimaryButton(
                          label: 'انطلق الآن 🚀',
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _submitLogin,
                        ).animate().fadeIn(delay: 400.ms),

                        SizedBox(height: 16.h),

                        // Registration prompt
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'ليس لديك حساب بطل بعد؟',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => context.push(AppRoutes.register),
                              child: Text(
                                'إنشاء حساب جديد',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),
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
