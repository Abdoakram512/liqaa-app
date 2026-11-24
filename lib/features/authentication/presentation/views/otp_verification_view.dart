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
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

/// Interactive OTP Verification screen where Yasser follows input progression.
class OtpVerificationView extends StatefulWidget {
  final String email;

  const OtpVerificationView({super.key, required this.email});

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  late YasserController _yasserController;
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _yasserController.dispose();
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      _yasserController.reactToValidation(true);
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verify();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verify() {
    final code = _otpCode;
    if (code.length != 4) {
      _yasserController.reactToValidation(false);
      return;
    }

    context.read<AuthCubit>().verifyOtp(email: widget.email, otp: code);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpVerified) {
          _yasserController.celebrate();
          context.push('${AppRoutes.resetPassword}?email=${Uri.encodeComponent(state.email)}');
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
                          'تأكيد الرمز',
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

                    // Attentive Yasser Character
                    YasserCharacter(
                      controller: _yasserController,
                      width: 200.w,
                      height: 230.h,
                      heroTag: 'yasser_otp_character',
                    ).animate().fadeIn(duration: 500.ms),

                    SizedBox(height: 12.h),

                    Text(
                      'أدخل الرمز المكون من 4 أرقام',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'تم إرسال الرمز إلى ${widget.email}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    SizedBox(height: 28.h),

                    // 4 Pin Input Boxes
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(4, (index) {
                          return SizedBox(
                            width: 60.w,
                            height: 64.h,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryLight.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              onChanged: (v) => _onDigitChanged(index, v),
                            ),
                          );
                        }),
                      ),
                    ),

                    SizedBox(height: 32.h),

                    PrimaryButton(
                      label: 'تأكيد الرمز والمتابعة ✅',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _verify,
                    ),

                    SizedBox(height: 16.h),

                    TextButton(
                      onPressed: () {
                        context.read<AuthCubit>().sendPasswordReset(widget.email);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تمت إعادة إرسال الرمز بنجاح!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('لم يصلك الرمز؟ إعادة الإرسال'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
