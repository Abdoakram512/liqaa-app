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
import '../../data/models/user_model.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

/// Premium Interactive Registration Screen where Yasser greets new children
/// and parents by name, responds to typing, and maintains privacy during password setup.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late YasserController _yasserController;
  late ConfettiController _confettiController;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  String _enteredName = '';
  UserRole _selectedRole = UserRole.child;

  @override
  void initState() {
    super.initState();
    _yasserController = YasserController();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _nameFocusNode.addListener(_handleNameFocus);
    _emailFocusNode.addListener(_handleEmailFocus);
    _passwordFocusNode.addListener(_handlePasswordFocus);
    _confirmPasswordFocusNode.addListener(_handlePasswordFocus);
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _yasserController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleNameFocus() {
    if (_nameFocusNode.hasFocus) {
      _yasserController.wave();
    } else if (!_isAnyPasswordFocused()) {
      _yasserController.returnToIdle();
    }
  }

  void _handleEmailFocus() {
    if (_emailFocusNode.hasFocus) {
      _yasserController.lookAtInput(normalizedX: 0.0, normalizedY: 0.35);
    } else if (!_isAnyPasswordFocused()) {
      _yasserController.returnToIdle();
    }
  }

  void _handlePasswordFocus() {
    if (_isAnyPasswordFocused()) {
      _yasserController.coverEyes();
    } else {
      _yasserController.uncoverEyes();
    }
  }

  bool _isAnyPasswordFocused() {
    return _passwordFocusNode.hasFocus || _confirmPasswordFocusNode.hasFocus;
  }

  void _handlePasswordVisibility(bool isVisible) {
    if (isVisible) {
      _yasserController.peek();
    } else {
      _yasserController.coverEyes();
    }
  }

  void _submitRegister() {
    if (!_formKey.currentState!.validate()) {
      _yasserController.reactToValidation(false);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _yasserController.reactToValidation(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('كلمتا المرور غير متطابقتين، يرجى التحقق منهما'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    context.read<AuthCubit>().register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          role: _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          _confettiController.play();
          _yasserController.celebrate(duration: const Duration(seconds: 3));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          Future.delayed(const Duration(milliseconds: 1600), () {
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
                              'حساب بطل جديد',
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

                        // Living Yasser Character
                        YasserCharacter(
                          controller: _yasserController,
                          width: 200.w,
                          height: 230.h,
                          heroTag: 'yasser_register_character',
                        ).animate().fadeIn(duration: 500.ms),

                        // Personalized Greeting Banner
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: _enteredName.isNotEmpty
                                ? AppColors.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Text(
                            _enteredName.isNotEmpty
                                ? 'أهلاً بك يا بطلنا الجديد: $_enteredName! 🎉'
                                : 'سعيد جداً بلقائك! ما اسمك الجميل؟',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        SizedBox(height: 12.h),

                        // Role Selector Pills (Child / Parent)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              label: const Text('بطل صغير 🧒'),
                              selected: _selectedRole == UserRole.child,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _selectedRole == UserRole.child ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (_) => setState(() => _selectedRole = UserRole.child),
                            ),
                            SizedBox(width: 12.w),
                            ChoiceChip(
                              label: const Text('ولي أمر / أخصائي 👨‍🏫'),
                              selected: _selectedRole == UserRole.parent,
                              selectedColor: AppColors.secondary,
                              labelStyle: TextStyle(
                                color: _selectedRole == UserRole.parent ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (_) => setState(() => _selectedRole = UserRole.parent),
                            ),
                          ],
                        ),

                        SizedBox(height: 16.h),

                        // Name Input
                        YasserTextField(
                          label: 'اسم البطل',
                          hint: 'مثال: يوسف، مريم، عمر...',
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          prefixIcon: const Icon(Icons.badge_rounded),
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

                        SizedBox(height: 14.h),

                        // Email Input
                        YasserTextField(
                          label: 'البريد الإلكتروني',
                          hint: 'name@example.com',
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_rounded),
                          validator: (v) {
                            if (v == null || !v.contains('@') || !v.contains('.')) {
                              return 'يرجى إدخال بريد إلكتروني صحيح';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 14.h),

                        // Password Field
                        YasserTextField(
                          label: 'كلمة المرور السرية',
                          hint: '6 خانات على الأقل',
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          isPassword: true,
                          prefixIcon: const Icon(Icons.lock_rounded),
                          onPasswordVisibilityChanged: _handlePasswordVisibility,
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'كلمة المرور يجب ألا تقل عن 6 خانات';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 14.h),

                        // Confirm Password Field
                        YasserTextField(
                          label: 'تأكيد كلمة المرور',
                          hint: 'أعد إدخال كلمة المرور',
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon: const Icon(Icons.lock_clock_rounded),
                          onPasswordVisibilityChanged: _handlePasswordVisibility,
                          onFieldSubmitted: _submitRegister,
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'كلمتا المرور غير متطابقتين';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 20.h),

                        // Register Action Button
                        PrimaryButton(
                          label: 'انضم إلى مغامرة لقاء ✨',
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _submitRegister,
                        ),

                        SizedBox(height: 14.h),

                        // Login prompt
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'لديك حساب بالفعل؟',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: Text(
                                'تسجيل الدخول',
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
