import 'dart:async';
import '../models/user_model.dart';
import '../sources/auth_local_data_source.dart';

/// Result type representing either a success value or a friendly error message.
class AuthResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const AuthResult.success(this.data)
      : error = null,
        isSuccess = true;

  const AuthResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

abstract class AuthRepo {
  Future<AuthResult<UserModel>> login({
    required String identity,
    required String password,
  });

  Future<AuthResult<UserModel>> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.child,
  });

  Future<AuthResult<bool>> sendPasswordReset({required String email});

  Future<AuthResult<bool>> verifyOtp({
    required String email,
    required String otp,
  });

  Future<AuthResult<bool>> resetPassword({
    required String email,
    required String newPassword,
  });

  Future<void> logout();

  Future<UserModel?> getCurrentUser();
}

/// Explicit Mock Authentication Repository for the MVP phase.
///
/// Simulates realistic network round-trips and predictable authentication
/// outcomes without requiring a live cloud backend.
class MockAuthRepo implements AuthRepo {
  final AuthLocalDataSource _localDataSource;

  MockAuthRepo(this._localDataSource);

  @override
  Future<AuthResult<UserModel>> login({
    required String identity,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 900));

    final trimmedIdentity = identity.trim();
    if (trimmedIdentity.isEmpty) {
      return const AuthResult.failure('يرجى إدخال اسم المستخدم أو البريد الإلكتروني');
    }

    if (password.length < 6) {
      return const AuthResult.failure('كلمة المرور يجب أن تتكون من 6 أحرف أو أرقام على الأقل');
    }

    // Predictable failure trigger for testing error feedback
    if (trimmedIdentity.toLowerCase() == 'error@liqaa.com' || password == 'wrongpass') {
      return const AuthResult.failure('بيانات الدخول غير صحيحة، يرجى المحاولة مرة أخرى');
    }

    final user = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedIdentity.contains('@')
          ? trimmedIdentity.split('@').first
          : trimmedIdentity,
      email: trimmedIdentity.contains('@') ? trimmedIdentity : '$trimmedIdentity@liqaa.com',
      role: UserRole.child,
      token: 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );

    await _localDataSource.saveUser(user);
    if (user.token != null) {
      await _localDataSource.saveToken(user.token!);
    }

    return AuthResult.success(user);
  }

  @override
  Future<AuthResult<UserModel>> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.child,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    if (trimmedName.isEmpty) {
      return const AuthResult.failure('يرجى إدخال اسم البطل أو ولي الأمر');
    }

    if (!trimmedEmail.contains('@') || !trimmedEmail.contains('.')) {
      return const AuthResult.failure('يرجى إدخال بريد إلكتروني صحيح');
    }

    if (password.length < 6) {
      return const AuthResult.failure('كلمة المرور يجب ألا تقل عن 6 خانات');
    }

    if (trimmedEmail == 'exists@liqaa.com') {
      return const AuthResult.failure('هذا البريد مسجل بالفعل في منصة لقاء');
    }

    final user = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      email: trimmedEmail,
      role: role,
      token: 'mock_jwt_registered_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );

    await _localDataSource.saveUser(user);
    if (user.token != null) {
      await _localDataSource.saveToken(user.token!);
    }

    return AuthResult.success(user);
  }

  @override
  Future<AuthResult<bool>> sendPasswordReset({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      return const AuthResult.failure('يرجى إدخال بريد إلكتروني صالح');
    }
    return const AuthResult.success(true);
  }

  @override
  Future<AuthResult<bool>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (otp.length != 4) {
      return const AuthResult.failure('رمز التحقق يجب أن يتكون من 4 أرقام');
    }
    if (otp == '0000') {
      return const AuthResult.failure('رمز التحقق غير صحيح، يرجى إعادة المحاولة');
    }
    return const AuthResult.success(true);
  }

  @override
  Future<AuthResult<bool>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (newPassword.length < 6) {
      return const AuthResult.failure('كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف');
    }
    return const AuthResult.success(true);
  }

  @override
  Future<void> logout() async {
    await _localDataSource.clearSession();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return _localDataSource.getUser();
  }
}
