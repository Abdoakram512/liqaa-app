import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;
import '../core/config/app_config.dart';
import 'dependency_injection/service_locator.dart';

Future<void> initDependencies() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize RiveNative C++ Runtime and Renderer
  try {
    await rive.RiveNative.init();
  } catch (e) {
    debugPrint('[Bootstrap] RiveNative initialization warning: $e');
  }

  // Initialize App Configuration
  AppConfig.initialize();

  // Setup Dependency Injection
  await setupServiceLocator();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
