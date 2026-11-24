import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';
import 'package:liqaa_app/features/authentication/data/models/user_model.dart';
import 'package:liqaa_app/features/authentication/data/repos/auth_repo.dart';
import 'package:liqaa_app/features/authentication/presentation/cubits/auth_cubit.dart';
import 'package:liqaa_app/features/authentication/presentation/views/login_view.dart';

class MockTestAuthRepo implements AuthRepo {
  @override
  Future<AuthResult<UserModel>> login({required String identity, required String password}) async {
    return AuthResult.success(
      UserModel(
        id: '1',
        name: identity,
        email: '$identity@test.com',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<AuthResult<UserModel>> register({required String name, required String email, required String password, UserRole role = UserRole.child}) async => throw UnimplementedError();

  @override
  Future<AuthResult<bool>> sendPasswordReset({required String email}) async => throw UnimplementedError();

  @override
  Future<AuthResult<bool>> verifyOtp({required String email, required String otp}) async => throw UnimplementedError();

  @override
  Future<AuthResult<bool>> resetPassword({required String email, required String newPassword}) async => throw UnimplementedError();

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

  testWidgets('LoginView renders character and form elements cleanly', (tester) async {
    final mockRepo = MockTestAuthRepo();
    final cubit = AuthCubit(mockRepo);

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

    await tester.pump(const Duration(milliseconds: 500));

    // Verify key fields exist
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('انطلق الآن 🚀'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(YasserCharacter), findsOneWidget);
  });
}
