enum Environment { dev, staging, prod }

final class AppConfig {
  final Environment environment;
  final String appTitle;
  final String apiBaseUrl;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;

  const AppConfig({
    required this.environment,
    required this.appTitle,
    required this.apiBaseUrl,
    this.connectTimeoutMs = 15000,
    this.receiveTimeoutMs = 15000,
  });

  static late final AppConfig current;

  static void initialize({
    Environment environment = Environment.dev,
    String? apiBaseUrl,
  }) {
    current = AppConfig(
      environment: environment,
      appTitle: 'LIQAA - لِقَاء',
      apiBaseUrl: apiBaseUrl ?? 'https://api.liqaa.app/v1',
    );
  }
}
