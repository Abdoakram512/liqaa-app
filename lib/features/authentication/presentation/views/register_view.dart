import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../../data/models/user_model.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';
import '../widgets/auth_stage_shell.dart';

/// Registration Screen exposing distinct Child, Parent, and Speech Specialist
/// role cards with live Yasser gaze, validation reactions, and password privacy.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final YasserController _yasserController;
  late final ConfettiController _confettiController;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _organizationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _organizationFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _visiblePasswords = <FocusNode, bool>{};

  String _enteredName = '';
  UserRole _selectedRole = UserRole.child;

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _nameController.addListener(_updateNameGaze);
    _emailController.addListener(_updateEmailGaze);
    _nameFocusNode.addListener(_handleCharacterFocus);
    _emailFocusNode.addListener(_handleCharacterFocus);
    _organizationFocusNode.addListener(_handleCharacterFocus);
    _passwordFocusNode.addListener(_handleCharacterFocus);
    _confirmPasswordFocusNode.addListener(_handleCharacterFocus);
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateNameGaze);
    _emailController.removeListener(_updateEmailGaze);
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _organizationFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _organizationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _yasserController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleCharacterFocus() {
    if (_passwordFocusNode.hasFocus || _confirmPasswordFocusNode.hasFocus) {
      final field = _passwordFocusNode.hasFocus
          ? _passwordFocusNode
          : _confirmPasswordFocusNode;
      if (_visiblePasswords[field] == true) {
        _yasserController.peek();
      } else {
        _yasserController.coverEyes();
      }
      setState(() {});
      return;
    }

    _yasserController.returnToIdle();
    if (_nameFocusNode.hasFocus) {
      _updateNameGaze();
    } else if (_emailFocusNode.hasFocus) {
      _updateEmailGaze();
    }
    setState(() {});
  }

  void _updateNameGaze() => _updateCaret(_nameFocusNode, _nameController);
  void _updateEmailGaze() => _updateCaret(_emailFocusNode, _emailController);

  void _updateCaret(FocusNode focus, TextEditingController text) {
    if (!focus.hasFocus) return;
    _yasserController.followCaret(
      text.selection.extentOffset,
      textLength: text.text.length,
      rightToLeft: Directionality.of(context) == TextDirection.rtl,
    );
  }

  void _handlePasswordVisibility(FocusNode field, bool visible) {
    _visiblePasswords[field] = visible;
    if (field.hasFocus) _handleCharacterFocus();
  }

  void _submitRegister() {
    if (!_formKey.currentState!.validate()) {
      _yasserController.reactToValidation(false);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _yasserController.reactToValidation(false);
      showYasserSnackBar(
        context,
        message: 'كلمتا المرور غير متطابقتين، يرجى التحقق منهما',
        tone: YasserBannerTone.error,
      );
      return;
    }

    context.read<AuthCubit>().register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      role: _selectedRole,
      organization: _selectedRole == UserRole.specialist
          ? _organizationController.text
          : null,
    );
  }

  String get _speechGreeting {
    if (_passwordFocusNode.hasFocus || _confirmPasswordFocusNode.hasFocus) {
      return 'سرّك محفوظ.. لن أنظر إلى كلمة المرور!';
    }
    if (_enteredName.isNotEmpty) {
      return switch (_selectedRole) {
        UserRole.specialist => 'تشرفت بك يا أ. $_enteredName في منصة لقاء!',
        UserRole.parent => 'أهلاً بك يا $_enteredName لمتابعة رحلة طفلك!',
        UserRole.child => 'أهلاً ببطلنا الجديد $_enteredName!',
      };
    }
    return switch (_selectedRole) {
      UserRole.specialist => 'حساب مهني لإدارة الحالات وجلسات النطق',
      UserRole.parent => 'حساب أسري لمشاركة طفلك التقدم اليومي',
      UserRole.child => 'سعيد بلقائك! اختر دورك واكتب اسمك الجميل',
    };
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

          Future.delayed(const Duration(milliseconds: 1050), () {
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
              title: 'إنشاء حساب جديد',
              speechTitle: _speechGreeting,
              yasserController: _yasserController,
              heroTag: 'yasser_register_character',
              formChild: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'اختر نوع الحساب',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // 3 Distinct Role Selection Cards
                    YasserSelectionCard(
                      title: 'بطل صغير',
                      subtitle:
                          'تمارين النطق التفاعلية والألعاب الصوتية مع ياسر',
                      icon: Icons.face_retouching_natural_rounded,
                      accentColor: AppColors.primary,
                      isSelected: _selectedRole == UserRole.child,
                      compact: true,
                      onTap: () =>
                          setState(() => _selectedRole = UserRole.child),
                    ),
                    SizedBox(height: 8.h),
                    YasserSelectionCard(
                      title: 'ولي أمر',
                      subtitle: 'متابعة جلسات الطفل المنزلية وتشجيعه باستمرار',
                      icon: Icons.family_restroom_rounded,
                      accentColor: AppColors.accentMintDark,
                      isSelected: _selectedRole == UserRole.parent,
                      compact: true,
                      onTap: () =>
                          setState(() => _selectedRole = UserRole.parent),
                    ),
                    SizedBox(height: 8.h),
                    YasserSelectionCard(
                      title: 'أخصائي تخاطب ونطق',
                      subtitle:
                          'إدارة ملفات الحالات، الجلسات، ومؤشرات التقدم الصوتية',
                      icon: Icons.psychology_rounded,
                      accentColor: AppColors.secondary,
                      isSelected: _selectedRole == UserRole.specialist,
                      compact: true,
                      onTap: () =>
                          setState(() => _selectedRole = UserRole.specialist),
                    ),

                    SizedBox(height: 18.h),

                    YasserTextField(
                      label: _selectedRole == UserRole.specialist
                          ? 'اسم الأخصائي الكامل'
                          : (_selectedRole == UserRole.parent
                                ? 'اسم ولي الأمر'
                                : 'اسم البطل'),
                      hint: _selectedRole == UserRole.specialist
                          ? 'مثال: د. سارة محمود'
                          : 'مثال: يوسف، مريم، عمر...',
                      variant: YasserFieldVariant.name,
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      showValidationSuccess: true,
                      onChanged: (val) {
                        setState(() => _enteredName = val.trim());
                        if (val.trim().length >= 3) {
                          _yasserController.reactToValidation(true);
                        }
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'يرجى كتابة الاسم';
                        }
                        return null;
                      },
                    ),

                    if (_selectedRole == UserRole.specialist) ...[
                      SizedBox(height: 14.h),
                      YasserTextField(
                        label: 'اسم المركز أو العيادة (اختياري)',
                        hint: 'مثال: مركز لقاء للتخاطب وتنمية المهارات',
                        variant: YasserFieldVariant.specialistCase,
                        controller: _organizationController,
                        focusNode: _organizationFocusNode,
                      ),
                    ],

                    SizedBox(height: 14.h),

                    YasserTextField(
                      label: 'البريد الإلكتروني',
                      hint: 'name@example.com',
                      variant: YasserFieldVariant.email,
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      showValidationSuccess: true,
                      validator: (v) {
                        if (v == null || !v.contains('@') || !v.contains('.')) {
                          return 'يرجى إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 14.h),

                    YasserTextField(
                      label: 'كلمة المرور السرية',
                      hint: '6 خانات على الأقل',
                      variant: YasserFieldVariant.password,
                      isPassword: true,
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      onPasswordVisibilityChanged: (visible) =>
                          _handlePasswordVisibility(
                            _passwordFocusNode,
                            visible,
                          ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'كلمة المرور يجب ألا تقل عن 6 خانات';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 14.h),

                    YasserTextField(
                      label: 'تأكيد كلمة المرور',
                      hint: 'أعد إدخال كلمة المرور',
                      variant: YasserFieldVariant.confirmPassword,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      onPasswordVisibilityChanged: (visible) =>
                          _handlePasswordVisibility(
                            _confirmPasswordFocusNode,
                            visible,
                          ),
                      onFieldSubmitted: _submitRegister,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'يرجى تأكيد كلمة المرور';
                        }
                        if (v != _passwordController.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20.h),

                    PrimaryButton(
                      label: _selectedRole == UserRole.specialist
                          ? 'إنشاء حساب الأخصائي'
                          : 'انضم إلى مغامرة لقاء',
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                      ),
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _submitRegister,
                    ),
                  ],
                ),
              ),
              footerChild: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'لديك حساب بالفعل؟',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushReplacement(AppRoutes.login),
                    child: const Text('تسجيل الدخول'),
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
