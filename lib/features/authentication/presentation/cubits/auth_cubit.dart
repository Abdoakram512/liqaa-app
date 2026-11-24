import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/repos/auth_repo.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo _authRepo;

  AuthCubit(this._authRepo) : super(const AuthInitial());

  Future<void> checkAuthStatus() async {
    final user = await _authRepo.getCurrentUser();
    if (user != null) {
      emit(AuthSuccess(user: user, message: 'مرحباً بك مجدداً يا ${user.name}!'));
    } else {
      emit(const AuthInitial());
    }
  }

  Future<void> login({
    required String identity,
    required String password,
  }) async {
    emit(const AuthLoading(operation: 'login'));
    final result = await _authRepo.login(
      identity: identity,
      password: password,
    );

    if (result.isSuccess && result.data != null) {
      emit(AuthSuccess(
        user: result.data!,
        message: 'تم تسجيل الدخول بنجاح! مرحباً بك يا ${result.data!.name} 🎉',
      ));
    } else {
      emit(AuthFailure(
        message: result.error ?? 'تعذر تسجيل الدخول، يرجى التحقق من بياناتك',
      ));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.child,
  }) async {
    emit(const AuthLoading(operation: 'register'));
    final result = await _authRepo.register(
      name: name,
      email: email,
      password: password,
      role: role,
    );

    if (result.isSuccess && result.data != null) {
      emit(AuthSuccess(
        user: result.data!,
        message: 'أهلاً بك في عائلة لقاء يا ${result.data!.name}! 🌟',
      ));
    } else {
      emit(AuthFailure(
        message: result.error ?? 'تعذر إنشاء الحساب، يرجى المحاولة مرة أخرى',
      ));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    emit(const AuthLoading(operation: 'reset_request'));
    final result = await _authRepo.sendPasswordReset(email: email);
    if (result.isSuccess) {
      emit(AuthOtpSent(email: email));
    } else {
      emit(AuthFailure(message: result.error ?? 'تعذر إرسال رمز الاستعادة'));
    }
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    emit(const AuthLoading(operation: 'verify_otp'));
    final result = await _authRepo.verifyOtp(email: email, otp: otp);
    if (result.isSuccess) {
      emit(AuthOtpVerified(email: email));
    } else {
      emit(AuthFailure(message: result.error ?? 'رمز التحقق غير صحيح'));
    }
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    emit(const AuthLoading(operation: 'set_new_password'));
    final result = await _authRepo.resetPassword(
      email: email,
      newPassword: newPassword,
    );
    if (result.isSuccess) {
      emit(const AuthPasswordResetSuccess(
        message: 'تم تحديث كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول',
      ));
    } else {
      emit(AuthFailure(message: result.error ?? 'فشل تعيين كلمة المرور الجديدة'));
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    emit(const AuthLoggedOut());
  }

  void resetToInitial() {
    emit(const AuthInitial());
  }
}
