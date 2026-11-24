import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ai/ai_model_manager.dart';
import '../../core/ai/audio_preprocessor.dart';
import '../../core/ai/audio_recorder_service.dart';
import '../../core/ai/phoneme_recognition_engine.dart';
import '../../core/ai/pronunciation_evaluator.dart';
import '../../core/ai/pronunciation_repository.dart';
import '../../core/ai/rnnoise_denoiser_engine.dart';
import '../../core/ai/silero_vad_engine.dart';
import '../../core/ai/speech_to_text_engine.dart';
import '../../core/networking/api_client.dart';
import '../../core/networking/dio_factory.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/storage/shared_prefs_service.dart';
import '../../features/ai_lab/cubits/ai_lab_cubit.dart';
import '../../features/onboarding/data/repos/onboarding_repo.dart';
import '../../features/onboarding/data/src/onboarding_local_data_source.dart';
import '../../features/onboarding/presentation/cubits/onboarding_cubit.dart';
import '../../features/pronunciation_game/cubits/pronunciation_game_cubit.dart';
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

  // AI & Speech Subsystem
  sl.registerLazySingleton<AudioRecorderService>(() => AudioRecorderService());
  sl.registerLazySingleton<AudioPreprocessor>(() => const AudioPreprocessor());
  sl.registerLazySingleton<SileroVadEngine>(() => SileroVadEngine());
  sl.registerLazySingleton<RnnoiseDenoiserEngine>(() => RnnoiseDenoiserEngine(preprocessor: sl()));
  sl.registerLazySingleton<PhonemeRecognitionEngine>(() => PhonemeRecognitionEngine());
  sl.registerLazySingleton<PronunciationEvaluator>(() => const PronunciationEvaluator());
  sl.registerLazySingleton<SpeechToTextEngine>(() => SpeechToTextEngine(preprocessor: sl()));
  sl.registerLazySingleton<AiModelManager>(() => AiModelManager());
  sl.registerLazySingleton<PronunciationRepository>(() => PronunciationRepository(
    recorder: sl(),
    preprocessor: sl(),
    vadEngine: sl(),
    denoiserEngine: sl(),
    phonemeEngine: sl(),
    evaluator: sl(),
    sttEngine: sl(),
    modelManager: sl(),
  ));

  // Cubits
  sl.registerFactory<SplashCubit>(() => SplashCubit(sl()));
  sl.registerFactory<OnboardingCubit>(() => OnboardingCubit(sl()));
  sl.registerFactory<AiLabCubit>(() => AiLabCubit(sl()));
  sl.registerFactory<PronunciationGameCubit>(() => PronunciationGameCubit(sl()));
}
