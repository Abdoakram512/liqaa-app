import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_state.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';
import 'package:liqaa_app/core/widgets/yasser_text_field.dart';
import 'package:liqaa_app/features/authentication/data/models/user_model.dart';
import 'package:liqaa_app/features/authentication/data/repos/auth_repo.dart';
import 'package:liqaa_app/features/authentication/presentation/cubits/auth_cubit.dart';
import 'package:liqaa_app/features/authentication/presentation/views/login_view.dart';

class MockTestAuthRepo implements AuthRepo {
  @override
  Future<AuthResult<UserModel>> login({
    required String identity,
    required String password,
    UserRole? preferredRole,
  }) async {
    return AuthResult.success(
      UserModel(
        id: '1',
        name: identity,
        email: '$identity@test.com',
        role: preferredRole ?? UserRole.child,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<AuthResult<UserModel>> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.child,
    String? organization,
  }) async => throw UnimplementedError();

  @override
  Future<AuthResult<bool>> sendPasswordReset({required String email}) async =>
      throw UnimplementedError();

  @override
  Future<AuthResult<bool>> verifyOtp({
    required String email,
    required String otp,
  }) async => throw UnimplementedError();

  @override
  Future<AuthResult<bool>> resetPassword({
    required String email,
    required String newPassword,
  }) async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel?> getCurrentUser() async => null;
}

void main() {
  setUp(() {
    YasserCharacter.enableRiveRuntime = false;
    YasserInteractionEngine.enableBlinkTimer = false;
  });

  tearDown(() {
    YasserCharacter.enableRiveRuntime = true;
    YasserInteractionEngine.enableBlinkTimer = true;
  });

  testWidgets(
    'LoginView releases privacy pose when focus returns to identity',
    (tester) async {
      final mockRepo = MockTestAuthRepo();
      final cubit = AuthCubit(mockRepo);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) => MaterialApp(
            home: BlocProvider<AuthCubit>.value(
              value: cubit,
              child: const LoginView(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1200));

      // Verify key fields exist
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('انطلق الآن'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      final character = tester.widget<YasserCharacter>(
        find.byType(YasserCharacter),
      );
      final fields = tester.widgetList<YasserTextField>(
        find.byType(YasserTextField),
      );

      fields.last.focusNode!.requestFocus();
      await tester.pump();
      expect(
        character.controller!.currentState,
        YasserAnimationState.coveringEyes,
      );

      final passwordField = find.byType(YasserTextField).last;
      final toggleButton = find.descendant(
        of: passwordField,
        matching: find.byType(IconButton),
      );
      await tester.ensureVisible(toggleButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(toggleButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(character.controller!.currentState, YasserAnimationState.peeking);

      fields.first.focusNode!.requestFocus();
      await tester.pump();
      expect(
        character.controller!.currentState,
        YasserAnimationState.followingInput,
      );

      final identityField = find.byType(TextFormField).first;
      final gazeAtStart = character.controller!.currentMapping.gazeTarget;
      await tester.enterText(identityField, 'example');
      await tester.pump();
      expect(
        character.controller!.currentMapping.gazeTarget,
        isNot(gazeAtStart),
      );

      fields.last.focusNode!.requestFocus();
      await tester.pump();
      expect(character.controller!.currentState, YasserAnimationState.peeking);
    },
  );
}
