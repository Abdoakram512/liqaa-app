import 'dart:convert';
import 'package:flutter/services.dart';

/// Reads the sanitized Phase 0 AI governance bundle (zero blind test labels exposed).
class Phase0GovernanceSummary {
  final String schemaVersion;
  final String generatedUtc;
  final String phaseStatus;
  final bool blindLabelsIncluded;
  final Map<String, dynamic> blindTestStatus;
  final Map<String, dynamic> storageAudit;
  final List<Map<String, dynamic>> modelsSummary;
  final Map<String, dynamic> legacyManifestReconciliation;
  final List<Map<String, dynamic>> datasetsSummary;
  final Map<String, dynamic> leakageAuditSummary;
  final List<Map<String, dynamic>> contaminationHighlights;
  final Map<String, dynamic> antiCheatingSummary;

  const Phase0GovernanceSummary({
    required this.schemaVersion,
    required this.generatedUtc,
    required this.phaseStatus,
    required this.blindLabelsIncluded,
    required this.blindTestStatus,
    required this.storageAudit,
    required this.modelsSummary,
    required this.legacyManifestReconciliation,
    required this.datasetsSummary,
    required this.leakageAuditSummary,
    required this.contaminationHighlights,
    required this.antiCheatingSummary,
  });

  factory Phase0GovernanceSummary.fromJson(Map<String, dynamic> json) {
    final bool hasBlindLabels = json['blind_labels_included'] as bool? ?? true;
    if (hasBlindLabels) {
      throw StateError(
        'BLIND_POLICY_VIOLATION: Runtime governance bundle must NEVER contain blind holdout labels.',
      );
    }

    List<Map<String, dynamic>> toMapList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return Phase0GovernanceSummary(
      schemaVersion: json['schema_version'] as String? ?? 'UNKNOWN',
      generatedUtc: json['generated_utc'] as String? ?? 'UNKNOWN',
      phaseStatus: json['phase_status'] as String? ?? 'UNKNOWN',
      blindLabelsIncluded: hasBlindLabels,
      blindTestStatus: Map<String, dynamic>.from(
        json['blind_test_status'] as Map? ?? const {},
      ),
      storageAudit: Map<String, dynamic>.from(
        json['storage_audit'] as Map? ?? const {},
      ),
      modelsSummary: toMapList(json['models_summary']),
      legacyManifestReconciliation: Map<String, dynamic>.from(
        json['legacy_manifest_reconciliation'] as Map? ?? const {},
      ),
      datasetsSummary: toMapList(json['datasets_summary']),
      leakageAuditSummary: Map<String, dynamic>.from(
        json['leakage_audit_summary'] as Map? ?? const {},
      ),
      contaminationHighlights: toMapList(json['contamination_highlights']),
      antiCheatingSummary: Map<String, dynamic>.from(
        json['anti_cheating_summary'] as Map? ?? const {},
      ),
    );
  }
}

class Phase0GovernanceService {
  static const String defaultAssetPath =
      'assets/ai_governance/phase0_summary.json';

  final AssetBundle _bundle;

  Phase0GovernanceService({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  Future<Phase0GovernanceSummary> loadSummary([
    String assetPath = defaultAssetPath,
  ]) async {
    final String raw = await _bundle.loadString(assetPath);
    final Map<String, dynamic> decoded =
        json.decode(raw) as Map<String, dynamic>;
    return Phase0GovernanceSummary.fromJson(decoded);
  }
}
