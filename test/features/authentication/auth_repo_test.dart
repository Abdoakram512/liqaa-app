import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/features/authentication/data/models/user_model.dart';
import 'package:liqaa_app/features/authentication/data/repos/auth_repo.dart';
import 'package:liqaa_app/features/authentication/data/sources/auth_local_data_source.dart';

class FakeAuthLocalDataSource implements AuthLocalDataSource {
  UserModel? _cachedUser;
  String? _cachedToken;

  @override
  Future<void> saveUser(UserModel user) async => _cachedUser = user;

  @override
  Future<UserModel?> getUser() async => _cachedUser;

  @override
  Future<void> saveToken(String token) async => _cachedToken = token;

  @override
  Future<String?> getToken() async => _cachedToken;

  @override
  Future<void> clearSession() async {
    _cachedUser = null;
    _cachedToken = null;
  }

  @override
  Future<bool> isLoggedIn() async => _cachedUser != null;
}

void main() {
  group('MockAuthRepo Tests', () {
    late FakeAuthLocalDataSource fakeLocalDataSource;
    late MockAuthRepo authRepo;

    setUp(() {
      fakeLocalDataSource = FakeAuthLocalDataSource();
      authRepo = MockAuthRepo(fakeLocalDataSource);
    });

    test('login with valid credentials succeeds and stores session', () async {
      final result = await authRepo.login(
        identity: 'yasser_hero',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.name, equals('yasser_hero'));
      expect(await fakeLocalDataSource.isLoggedIn(), isTrue);
    });

    test('login with short password returns validation failure', () async {
      final result = await authRepo.login(
        identity: 'ahmed',
        password: '123',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('6 أحرف'));
    });

    test('login with error trigger returns failure', () async {
      final result = await authRepo.login(
        identity: 'error@liqaa.com',
        password: 'password123',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('غير صحيحة'));
    });

    test('register with valid details creates user', () async {
      final result = await authRepo.register(
        name: 'كريم',
        email: 'karim@example.com',
        password: 'securePass123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.name, equals('كريم'));
      expect(result.data!.email, equals('karim@example.com'));
    });

    test('sendPasswordReset with invalid email returns failure', () async {
      final result = await authRepo.sendPasswordReset(email: 'invalid-email');
      expect(result.isSuccess, isFalse);
    });

    test('verifyOtp returns true for valid code', () async {
      final result = await authRepo.verifyOtp(email: 'test@liqaa.com', otp: '1234');
      expect(result.isSuccess, isTrue);
    });

    test('logout clears local session', () async {
      await authRepo.login(identity: 'test', password: 'password123');
      expect(await fakeLocalDataSource.isLoggedIn(), isTrue);

      await authRepo.logout();
      expect(await fakeLocalDataSource.isLoggedIn(), isFalse);
    });
  });
}
