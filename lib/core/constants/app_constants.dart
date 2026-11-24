import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const String appName = 'LIQAA';
  static const String appArabicName = 'لِقَاء';

  // Locales
  static const Locale arabicLocale = Locale('ar');
  static const Locale englishLocale = Locale('en');
  static const List<Locale> supportedLocales = [arabicLocale, englishLocale];

  // Animation Durations
  static const Duration splashDelay = Duration(milliseconds: 2200);
  static const Duration defaultAnimationDuration = Duration(milliseconds: 350);
  static const Duration pageTransitionDuration = Duration(milliseconds: 400);

  // ScreenUtil Design Size
  static const Size designSize = Size(390, 844);
}
