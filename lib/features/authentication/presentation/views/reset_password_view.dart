import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';
import '../widgets/auth_stage_shell.dart';

/// Reset Password screen preserving Yasser's eye-covering privacy reactions.
class ResetPasswordView extends StatefulWidget {
  final String email;

  const ResetPasswordView({super.key, required this.email});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  late final YasserController _yasserController;
  late final ConfettiController _confettiController;
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
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

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
    setState(() {});
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
      showYasserSnackBar(
        context,
        message: 'كلمتا المرور غير متطابقتين',
        tone: YasserBannerTone.error,
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

          showYasserSnackBar(
            context,
            message: state.message,
            tone: YasserBannerTone.success,
          );

          Future.delayed(const Duration(milliseconds: 1100), () {
            if (context.mounted) {
              context.go(AppRoutes.login);
            }
          });
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
          body: ConfettiCelebrationOverlay(
            confettiController: _confettiController,
            child: AuthStageShell(
              title: 'كلمة مرور جديدة',
              speechTitle:
                  (_passwordFocusNode.hasFocus ||
                      _confirmPasswordFocusNode.hasFocus)
                  ? 'مغمّض عيوني.. اختار كلمة مرور قوية!'
                  : 'اكتب كلمة المرور الجديدة واحفظها بأمان',
              yasserController: _yasserController,
              heroTag: 'yasser_reset_character',
              formChild: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    YasserTextField(
                      label: 'كلمة المرور الجديدة',
                      hint: '6 خانات على الأقل',
                      variant: YasserFieldVariant.password,
                      isPassword: true,
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      onPasswordVisibilityChanged: (visible) =>
                          _handleVisibility(_passwordFocusNode, visible),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'يجب أن تتكون من 6 خانات على الأقل';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    YasserTextField(
                      label: 'تأكيد كلمة المرور الجديدة',
                      hint: 'أعد كتابة كلمة المرور',
                      variant: YasserFieldVariant.confirmPassword,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
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
                    SizedBox(height: 22.h),
                    PrimaryButton(
                      label: 'حفظ كلمة المرور والدخول',
                      icon: const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                      ),
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _submit,
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
