import 'package:dio/dio.dart';
import '../config/app_config.dart';

class DioFactory {
  static Dio createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.current.apiBaseUrl,
        connectTimeout: Duration(
          milliseconds: AppConfig.current.connectTimeoutMs,
        ),
        receiveTimeout: Duration(
          milliseconds: AppConfig.current.receiveTimeoutMs,
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );

    return dio;
  }
}
