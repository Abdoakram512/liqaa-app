import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/asset_paths.dart';

void main() async {
  await initDependencies();

  runApp(
    EasyLocalization(
      supportedLocales: AppConstants.supportedLocales,
      path: AssetPaths.translationsDir,
      fallbackLocale: AppConstants.arabicLocale,
      startLocale: AppConstants.arabicLocale,
      child: const LiqaaApp(),
    ),
  );
}
