import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';
import '../widgets/auth_stage_shell.dart';

/// Forgot Password screen integrated into Yasser's adaptive stage shell.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  late final YasserController _yasserController;
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _yasserController.think(duration: const Duration(seconds: 4));
      }
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
          context.push(
            '${AppRoutes.otpVerification}?email=${Uri.encodeComponent(state.email)}',
          );
        } else if (state is AuthFailure) {
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
            title: 'استعادة الحساب',
            speechTitle: 'ولا يهمك! هنساعدك تسترجع حسابك فوراً',
            speechSubtitle:
                'أدخل بريدك الإلكتروني لإرسال رمز التحقق المكون من 4 أرقام',
            yasserController: _yasserController,
            heroTag: 'yasser_forgot_character',
            formChild: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YasserTextField(
                    label: 'البريد الإلكتروني المسجل',
                    hint: 'name@example.com',
                    variant: YasserFieldVariant.email,
                    controller: _emailController,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: _submit,
                    validator: (v) {
                      if (v == null || !v.contains('@')) {
                        return 'يرجى إدخال بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20.h),
                  PrimaryButton(
                    label: 'إرسال رمز التحقق',
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
