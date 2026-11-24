import '../../../../core/storage/shared_prefs_service.dart';

abstract class OnboardingLocalDataSource {
  bool isOnboardingCompleted();
  Future<bool> setOnboardingCompleted(bool completed);
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  final SharedPrefsService _sharedPrefsService;

  OnboardingLocalDataSourceImpl(this._sharedPrefsService);

  @override
  bool isOnboardingCompleted() {
    return _sharedPrefsService.isOnboardingCompleted();
  }

  @override
  Future<bool> setOnboardingCompleted(bool completed) async {
    return await _sharedPrefsService.setOnboardingCompleted(completed);
  }
}
