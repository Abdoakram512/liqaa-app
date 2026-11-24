import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/networking/api_client.dart';
import '../../core/networking/dio_factory.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/storage/shared_prefs_service.dart';
import '../../features/onboarding/data/repos/onboarding_repo.dart';
import '../../features/onboarding/data/src/onboarding_local_data_source.dart';
import '../../features/onboarding/presentation/cubits/onboarding_cubit.dart';
import '../../features/splash/presentation/cubits/splash_cubit.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Local Storage
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  sl.registerLazySingleton<SharedPrefsService>(() => SharedPrefsService(sl()));
  sl.registerLazySingleton<SecureStorageService>(
    () => const SecureStorageService(),
  );

  // Networking
  sl.registerLazySingleton<Dio>(() => DioFactory.createDio());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));

  // Data Sources & Repositories
  sl.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<OnboardingRepo>(() => OnboardingRepo(sl()));

  // Cubits
  sl.registerFactory<SplashCubit>(() => SplashCubit(sl()));
  sl.registerFactory<OnboardingCubit>(() => OnboardingCubit(sl()));
}
