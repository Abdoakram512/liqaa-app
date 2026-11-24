import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

/// Interactive Forgot Password screen where Yasser thinks and reassures the user.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  late YasserController _yasserController;
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
    // Yasser enters thoughtful puzzle-solving pose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _yasserController.think(duration: const Duration(seconds: 4));
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _yasserController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      _yasserController.reactToValidation(false);
      return;
    }

    context.read<AuthCubit>().sendPasswordReset(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          _yasserController.wave();
          context.push('${AppRoutes.otpVerification}?email=${Uri.encodeComponent(state.email)}');
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
          body: PhonologicalBackground(
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
                            'استعادة الحساب',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),

                      SizedBox(height: 16.h),

                      // Yasser Thinking Character
                      YasserCharacter(
                        controller: _yasserController,
                        width: 210.w,
                        height: 240.h,
                        heroTag: 'yasser_forgot_character',
                      ).animate().fadeIn(duration: 500.ms),

                      SizedBox(height: 12.h),

                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowWarm,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'لا تقلق يا بطل! سأساعدك في استعادة حسابك',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'أدخل بريدك الإلكتروني وسنرسل لك رمز تحقق سريع من 4 أرقام.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24.h),

                      YasserTextField(
                        label: 'البريد الإلكتروني المسجل',
                        hint: 'name@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                        validator: (v) {
                          if (v == null || !v.contains('@')) {
                            return 'يرجى إدخال بريد إلكتروني صحيح';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24.h),

                      PrimaryButton(
                        label: 'إرسال رمز التحقق ✉️',
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _submit,
                      ),
                    ],
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
