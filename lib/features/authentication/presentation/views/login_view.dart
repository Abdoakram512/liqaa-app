import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../../data/models/user_model.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';
import '../widgets/auth_stage_shell.dart';

/// Interactive Login Screen where Yasser responds to identity gaze, covers his
/// eyes on password focus, peeks on password reveal, and routes by user role.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final YasserController _yasserController;
  late final ConfettiController _confettiController;
  final _formKey = GlobalKey<FormState>();

  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();

  final _identityFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _rememberMe = true;
  bool _passwordVisible = false;
  UserRole? _selectedPortalRole;

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

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
      setState(() {});
    } else if (!_passwordFocusNode.hasFocus) {
      _yasserController.returnToIdle();
      setState(() {});
    }
  }

  void _handlePasswordFocus() {
    if (_passwordFocusNode.hasFocus) {
      _handlePasswordVisibility(_passwordVisible);
      setState(() {});
    } else {
      _yasserController.uncoverEyes();
      if (_identityFocusNode.hasFocus) {
        _updateIdentityGaze();
      }
      setState(() {});
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
    setState(() {});
  }

  void _submitLogin() {
    if (!_formKey.currentState!.validate()) {
      _yasserController.reactToValidation(false);
      return;
    }

    context.read<AuthCubit>().login(
      identity: _identityController.text,
      password: _passwordController.text,
      preferredRole: _selectedPortalRole,
    );
  }

  String get _dynamicSpeechTitle {
    if (_passwordFocusNode.hasFocus) {
      return _passwordVisible
          ? 'نظرة سريعة فقط.. سرّك في أمان!'
          : 'مغمّض عيوني علشان كلمة السر بتاعتك!';
    }
    if (_identityFocusNode.hasFocus) {
      return 'اكتب اسمك أو بريدك يا صديقي!';
    }
    if (_selectedPortalRole == UserRole.specialist) {
      return 'أهلاً بك في بوابة أخصائي التخاطب';
    }
    return 'وحشتني يا بطل! يلا نسجّل دخولنا';
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

          showYasserSnackBar(
            context,
            message: state.message,
            tone: YasserBannerTone.success,
          );

          final targetRoute = state.user.role == UserRole.specialist
              ? AppRoutes.specialistDashboard
              : AppRoutes.home;

          Future.delayed(const Duration(milliseconds: 950), () {
            if (context.mounted) {
              context.go(targetRoute);
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
              title: 'تسجيل الدخول',
              speechTitle: _dynamicSpeechTitle,
              speechSubtitle:
                  'استخدم حسابك المحلي للطفل أو ولي الأمر أو الأخصائي',
              yasserController: _yasserController,
              heroTag: 'yasser_login_character',
              formChild: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Optional Portal Mode Switcher (Child/Parent vs Specialist)
                    Row(
                      children: [
                        Expanded(
                          child: _PortalModeTab(
                            label: 'البطل / الأسرة',
                            icon: Icons.face_retouching_natural_rounded,
                            selected:
                                _selectedPortalRole != UserRole.specialist,
                            accent: AppColors.primary,
                            onTap: () =>
                                setState(() => _selectedPortalRole = null),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _PortalModeTab(
                            label: 'الأخصائي',
                            icon: Icons.psychology_rounded,
                            selected:
                                _selectedPortalRole == UserRole.specialist,
                            accent: AppColors.secondary,
                            onTap: () => setState(
                              () => _selectedPortalRole = UserRole.specialist,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 18.h),

                    YasserTextField(
                      label: _selectedPortalRole == UserRole.specialist
                          ? 'البريد المهني أو اسم الأخصائي'
                          : 'اسم البطل أو البريد الإلكتروني',
                      hint: _selectedPortalRole == UserRole.specialist
                          ? 'dr.ahmed@clinic.org'
                          : 'مثال: يوسف أو youssef@liqaa.local',
                      variant: YasserFieldVariant.email,
                      controller: _identityController,
                      focusNode: _identityFocusNode,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال اسم المستخدم أو البريد الإلكتروني';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    YasserTextField(
                      label: 'كلمة المرور السرية',
                      hint: '6 خانات على الأقل',
                      variant: YasserFieldVariant.password,
                      isPassword: true,
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      textInputAction: TextInputAction.done,
                      onPasswordVisibilityChanged: _handlePasswordVisibility,
                      onFieldSubmitted: _submitLogin,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'كلمة المرور يجب أن تتكون من 6 خانات على الأقل';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 8.h),

                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.w,
                      runSpacing: 4.h,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? true),
                            ),
                            Flexible(
                              child: Text(
                                'تذكرني على هذا الجهاز',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.forgotPassword),
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    PrimaryButton(
                      label: 'انطلق الآن',
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _submitLogin,
                    ),
                  ],
                ),
              ),
              footerChild: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'ليس لديك حساب بعد؟',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.register),
                    child: const Text('إنشاء حساب جديد'),
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

class _PortalModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _PortalModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: YasserMotion.microState,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: ShapeDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : AppColors.surfaceSubtle,
          shape: YasserShapes.squircle(
            14,
            side: BorderSide(
              color: selected ? accent : AppColors.borderSoft,
              width: selected ? 2.0 : 1.2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? accent : AppColors.textSecondary,
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
