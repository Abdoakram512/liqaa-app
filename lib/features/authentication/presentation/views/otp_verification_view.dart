import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_otp_field.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';
import '../widgets/auth_stage_shell.dart';

/// OTP Verification view using tactile squircle [YasserOtpField].
class OtpVerificationView extends StatefulWidget {
  final String email;

  const OtpVerificationView({super.key, required this.email});

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  late final YasserController _yasserController;
  final GlobalKey<YasserOtpFieldState> _otpKey =
      GlobalKey<YasserOtpFieldState>();
  String _code = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
  }

  @override
  void dispose() {
    _yasserController.dispose();
    super.dispose();
  }

  void _verify([String? completedCode]) {
    final code = completedCode ?? _code;
    if (code.length != 4) {
      setState(() => _hasError = true);
      _yasserController.reactToValidation(false);
      return;
    }

    setState(() => _hasError = false);
    context.read<AuthCubit>().verifyOtp(email: widget.email, otp: code);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpVerified) {
          _yasserController.celebrate();
          context.push(
            '${AppRoutes.resetPassword}?email=${Uri.encodeComponent(state.email)}',
          );
        } else if (state is AuthFailure) {
          setState(() => _hasError = true);
          _yasserController.reactToValidation(false);
          showYasserSnackBar(
            context,
            message: state.message,
            tone: YasserBannerTone.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          body: AuthStageShell(
            title: 'تأكيد الرمز',
            speechTitle: 'أدخل الرمز المكون من 4 أرقام',
            speechSubtitle: widget.email.isNotEmpty
                ? 'تم إرسال رمز التحقق إلى ${widget.email}'
                : 'اكتب الأرقام الأربعة بالترتيب للمتابعة',
            yasserController: _yasserController,
            heroTag: 'yasser_otp_character',
            formChild: Column(
              children: [
                YasserOtpField(
                  key: _otpKey,
                  hasError: _hasError,
                  enabled: !isLoading,
                  onChanged: (value) {
                    setState(() {
                      _code = value;
                      if (_hasError) _hasError = false;
                    });
                    if (value.isNotEmpty) {
                      _yasserController.reactToValidation(true);
                    }
                  },
                  onCompleted: _verify,
                ),
                if (_hasError) ...[
                  SizedBox(height: 10.h),
                  Text(
                    'يرجى إدخال رمز صحيح مكون من 4 أرقام (أي رمز غير 0000 في الوضع المحلي)',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.errorDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                SizedBox(height: 22.h),
                PrimaryButton(
                  label: 'تأكيد الرمز والمتابعة',
                  icon: const Icon(Icons.verified_rounded, color: Colors.white),
                  isLoading: isLoading,
                  onPressed: isLoading ? null : () => _verify(),
                ),
                SizedBox(height: 10.h),
                TextButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          _otpKey.currentState?.clear();
                          context.read<AuthCubit>().sendPasswordReset(
                            widget.email,
                          );
                          showYasserSnackBar(
                            context,
                            message: 'تمت إعادة إرسال الرمز بنجاح',
                            tone: YasserBannerTone.info,
                          );
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('لم يصلك الرمز؟ إعادة الإرسال'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
