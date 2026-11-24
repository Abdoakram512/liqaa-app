abstract final class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';

  // Authentication Routes
  static const String auth = '/auth';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String otpVerification = '/otp-verification';
  static const String resetPassword = '/reset-password';

  // Character & Lab Routes
  static const String animationLab = '/animation-lab';
  static const String riveDiagnostic = '/rive-diagnostic';

  // Game & AI Lab Routes
  static const String game = '/game';
  static const String aiLab = '/ai-lab';
  static const String aiLabModels = '/ai-lab/models';
  static const String aiLabVad = '/ai-lab/vad';
  static const String aiLabNoise = '/ai-lab/noise';
  static const String aiLabPhonemes = '/ai-lab/phonemes';
  static const String aiLabStt = '/ai-lab/stt';
  static const String aiLabCompare = '/ai-lab/compare';
  static const String aiLabPipeline = '/ai-lab/pipeline';
}
