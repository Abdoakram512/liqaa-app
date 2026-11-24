import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/features/authentication/data/models/user_model.dart';
import 'package:liqaa_app/features/authentication/data/repos/auth_repo.dart';
import 'package:liqaa_app/features/authentication/presentation/cubits/auth_cubit.dart';
import 'package:liqaa_app/features/authentication/presentation/cubits/auth_state.dart';

class StubAuthRepo implements AuthRepo {
  bool shouldSucceed = true;
  String errorMessage = 'فشل الاختبار';

  @override
  Future<AuthResult<UserModel>> login({
    required String identity,
    required String password,
  }) async {
    if (shouldSucceed) {
      return AuthResult.success(
        UserModel(
          id: '1',
          name: identity,
          email: '$identity@test.com',
          createdAt: DateTime.now(),
        ),
      );
    }
    return AuthResult.failure(errorMessage);
  }

  @override
  Future<AuthResult<UserModel>> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.child,
  }) async {
    if (shouldSucceed) {
      return AuthResult.success(
        UserModel(
          id: '2',
          name: name,
          email: email,
          role: role,
          createdAt: DateTime.now(),
        ),
      );
    }
    return AuthResult.failure(errorMessage);
  }

  @override
  Future<AuthResult<bool>> sendPasswordReset({required String email}) async {
    return shouldSucceed ? const AuthResult.success(true) : AuthResult.failure(errorMessage);
  }

  @override
  Future<AuthResult<bool>> verifyOtp({required String email, required String otp}) async {
    return shouldSucceed ? const AuthResult.success(true) : AuthResult.failure(errorMessage);
  }

  @override
  Future<AuthResult<bool>> resetPassword({required String email, required String newPassword}) async {
    return shouldSucceed ? const AuthResult.success(true) : AuthResult.failure(errorMessage);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel?> getCurrentUser() async => null;
}

void main() {
  group('AuthCubit Tests', () {
    late StubAuthRepo stubRepo;
    late AuthCubit cubit;

    setUp(() {
      stubRepo = StubAuthRepo();
      cubit = AuthCubit(stubRepo);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is AuthInitial', () {
      expect(cubit.state, equals(const AuthInitial()));
    });

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthSuccess] on successful login',
      build: () => cubit,
      act: (c) => c.login(identity: 'yasser', password: 'password123'),
      expect: () => [
        const AuthLoading(operation: 'login'),
        isA<AuthSuccess>().having((s) => s.user.name, 'name', 'yasser'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthFailure] on failed login',
      build: () {
        stubRepo.shouldSucceed = false;
        return cubit;
      },
      act: (c) => c.login(identity: 'wrong', password: 'password123'),
      expect: () => [
        const AuthLoading(operation: 'login'),
        isA<AuthFailure>(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthSuccess] on successful registration',
      build: () => cubit,
      act: (c) => c.register(name: 'مريم', email: 'maryam@test.com', password: 'pass12345'),
      expect: () => [
        const AuthLoading(operation: 'register'),
        isA<AuthSuccess>().having((s) => s.user.name, 'name', 'مريم'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthOtpSent] on password reset request',
      build: () => cubit,
      act: (c) => c.sendPasswordReset('user@test.com'),
      expect: () => [
        const AuthLoading(operation: 'reset_request'),
        const AuthOtpSent(email: 'user@test.com'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthOtpVerified] on OTP verify',
      build: () => cubit,
      act: (c) => c.verifyOtp(email: 'user@test.com', otp: '1234'),
      expect: () => [
        const AuthLoading(operation: 'verify_otp'),
        const AuthOtpVerified(email: 'user@test.com'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthPasswordResetSuccess] on reset password',
      build: () => cubit,
      act: (c) => c.resetPassword(email: 'user@test.com', newPassword: 'newPassword123'),
      expect: () => [
        const AuthLoading(operation: 'set_new_password'),
        isA<AuthPasswordResetSuccess>(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoggedOut] on logout',
      build: () => cubit,
      act: (c) => c.logout(),
      expect: () => [
        const AuthLoggedOut(),
      ],
    );
  });
}
