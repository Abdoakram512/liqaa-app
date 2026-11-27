import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/phase0_governance_service.dart';
import 'package:liqaa_app/core/theme/app_theme.dart';
import 'package:liqaa_app/features/ai_lab/views/phase0_governance_view.dart';

class _DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return File(key).readAsStringSync();
  }
}

void main() {
  test(
    'AI_MODELS_MANIFEST.json contains all active runtime keys and valid files',
    () {
      final file = File('AI_MODELS_MANIFEST.json');
      expect(file.existsSync(), isTrue);
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final models = decoded['models'] as Map<String, dynamic>;

      for (final key in [
        'silero_vad',
        'gtcrn_denoiser',
        'wav2vec2_espeak',
        'whisper_tiny',
      ]) {
        expect(models.containsKey(key), isTrue, reason: 'Missing $key');
        final entry = models[key] as Map<String, dynamic>;
        expect(entry['ready'], isTrue);
        final files = entry['files'] as Map<String, dynamic>;
        for (final fEntry in files.values.whereType<Map<String, dynamic>>()) {
          final path = fEntry['path'] as String;
          expect(File(path).existsSync(), isTrue, reason: 'Missing file $path');
          expect(File(path).lengthSync(), fEntry['size_bytes']);
        }
      }
      expect((models['rnnoise'] as Map<String, dynamic>)['ready'], isFalse);
    },
  );

  test(
    'phase0_summary.json loads without blind labels and passes 15/15 checks',
    () async {
      final service = Phase0GovernanceService(bundle: _DiskAssetBundle());
      final summary = await service.loadSummary();

      expect(summary.blindLabelsIncluded, isFalse);
      expect(summary.modelsSummary.length, greaterThanOrEqualTo(13));
      expect(summary.datasetsSummary.length, greaterThanOrEqualTo(9));
      expect(summary.legacyManifestReconciliation['issue_count'], 0);
      expect(summary.antiCheatingSummary['passed_count'], 15);
      expect(summary.blindTestStatus['synthetic_allowed_in_stage_b'], isFalse);
    },
  );

  test(
    'Phase0GovernanceService rejects tampered bundle exposing blind labels',
    () {
      expect(
        () => Phase0GovernanceSummary.fromJson({'blind_labels_included': true}),
        throwsStateError,
      );
    },
  );

  testWidgets('Phase0GovernanceView renders all three tabs cleanly', (
    tester,
  ) async {
    final service = Phase0GovernanceService(bundle: _DiskAssetBundle());
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Phase0GovernanceView(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Phase0GovernanceView), findsOneWidget);
    expect(find.textContaining('Silero VAD'), findsWidgets);

    await tester.tap(find.text('البيانات والأعمى'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stage B'), findsWidgets);

    await tester.tap(find.text('التسرب والاختبارات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تخزين السحابة'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('15/15'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('15/15'), findsWidgets);
  });
}
