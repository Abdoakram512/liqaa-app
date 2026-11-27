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

  // Primary Product Hubs
  static const String home = '/home';
  static const String profileSetup = '/profile-setup';
  static const String adventureDetail = '/adventure/:regionId';
  static const String activity = '/activity/:gameType';
  static const String specialistDashboard = '/specialist';
  static const String specialistCaseDetail = '/specialist/cases/:caseId';

  static String adventurePath(String regionId) => '/adventure/$regionId';
  static String activityPath(String gameType) => '/activity/$gameType';

  static String specialistCasePath(String caseId) =>
      '/specialist/cases/$caseId';

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
  static const String aiLabBenchmark = '/ai-lab/benchmark';
  static const String aiLabBlind = '/ai-lab/blind';
  static const String aiLabNegative = '/ai-lab/negative';
  static const String aiLabSuite = '/ai-lab/suite';
  static const String aiLabGovernance = '/ai-lab/governance';
}
