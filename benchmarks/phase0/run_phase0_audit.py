"""End-to-end Phase 0 audit runner: builds registries, runs real leakage & integrity checks."""

from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .anti_cheating_suite import run_all_15_anti_cheating_tests
from .contamination_matrix import CONTAMINATION_MATRIX_PATH, write_contamination_matrix
from .dataset_registry import DATASET_REGISTRY_PATH, write_dataset_registry
from .leakage_engine import run_leakage_audit
from .model_registry import MODEL_REGISTRY_PATH, write_model_registry
from .workspace_config import PHASE0_DIR, REPO_ROOT, YasserWorkspaceConfig, ensure_workspace


def audit_existing_project_manifests(cfg: YasserWorkspaceConfig) -> dict[str, Any]:
    """Scan existing historical 100-sample manifest + controlled manifest + bundled audio_samples."""
    records: list[dict[str, Any]] = []

    m_path = REPO_ROOT / "benchmarks" / "audio" / "manifest.jsonl"
    if m_path.exists():
        for line in m_path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            r = json.loads(line)
            records.append(
                {
                    "sample_id": r["sample_id"],
                    "split": "historical_benchmark_100",
                    "dataset_id": r.get("original_dataset", "UNKNOWN"),
                    "speaker_id": r.get("speaker_id", ""),
                    "category": r.get("category", ""),
                    "audio_type": r.get("audio_type", ""),
                    "actual_speech_present": r.get("actual_speech_present"),
                    "file_path": r.get("file_path", ""),
                    "actual_spoken_word": r.get("actual_spoken_word", ""),
                    "sha256": r.get("sha256", ""),
                }
            )

    c_path = REPO_ROOT / "benchmarks" / "audio" / "controlled_manifest.jsonl"
    if c_path.exists():
        for line in c_path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            r = json.loads(line)
            if r["type"] == "paired_noisy_speech":
                records.append(
                    {
                        "sample_id": r["id"],
                        "split": "controlled_paired_snr",
                        "dataset_id": "MUSAN+Abjad_Paired",
                        "parent_source_id": r.get("source_sample_id", ""),
                        "audio_type": "human_pediatric_derived",
                        "file_path": r.get("noisy_path", ""),
                    }
                )
            elif r["type"] == "controlled_synthetic_tts":
                records.append(
                    {
                        "sample_id": r["id"],
                        "split": "controlled_synthetic_tts",
                        "dataset_id": "LIQAA_Synthetic_TTS",
                        "audio_type": "controlled_synthetic",
                        "file_path": r.get("path", ""),
                    }
                )

    report = run_leakage_audit(records, REPO_ROOT)
    # Also note Stage A vs Stage B readiness status honestly
    return {
        "manifest_records_scanned": len(records),
        "leakage_audit": report.to_dict(),
        "historical_split_warning": (
            "The historical 100-sample benchmark clips + 23 controlled entries belong to Stage A calibration/historical audit ONLY; "
            "they MUST NEVER enter Stage B Blind Holdout."
        ),
    }


def export_sanitized_flutter_governance_bundle(
    cfg: YasserWorkspaceConfig,
    workspace_info: dict[str, Any],
    model_reg: dict[str, Any],
    dataset_reg: dict[str, Any],
    matrix_rows: list[dict[str, Any]],
    manifest_leakage: dict[str, Any],
    anti_cheating: dict[str, Any],
) -> Path:
    """Write sanitized, blind-label-free Phase 0 governance snapshot for Flutter Yasser AI Lab UI."""
    out_dir = REPO_ROOT / "assets" / "ai_governance"
    out_dir.mkdir(parents=True, exist_ok=True)

    # Strictly strip any sensitive raw file paths / blind labels (zero Stage B labels exist here)
    sanitized_summary = {
        "schema_version": "0.1.0-phase0",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "phase_status": "PHASE_0_EXECUTED_PRE_STAGE_AB_ACQUISITION",
        "blind_labels_included": False,
        "blind_test_status": {
            "stage_a_target_samples": dataset_reg["split_quotas"]["stage_a"]["total_target_samples"],
            "stage_a_collected_legacy_audit_clips": manifest_leakage["manifest_records_scanned"],
            "stage_b_target_samples": dataset_reg["split_quotas"]["stage_b_blind"]["total_target_samples"],
            "stage_b_frozen": False,
            "stage_b_reason": "Awaiting independent human Stage B corpus build in Phase 3; zero Stage B labels exposed in app bundle.",
            "synthetic_allowed_in_stage_b": False,
            "vault_location": str(cfg.blind_vault_dir),
        },
        "storage_audit": workspace_info["storage_report"],
        "models_summary": [
            {
                "model_id": m["model_id"],
                "display_name": m["display_name"],
                "category": m["category"],
                "license": m["license"],
                "commercial_use_allowed": m["commercial_use_allowed"],
                "availability_status": m["availability_status"],
                "artifact_size_mb": m["artifact_size_mb"],
                "supports_blind_phoneme_only": m["supports_blind_phoneme_only"],
                "requires_target_word_hint": m["requires_target_word_hint"],
                "contamination_risk_notes": m["contamination_risk_notes"],
            }
            for m in model_reg["models"]
        ],
        "legacy_manifest_reconciliation": model_reg["legacy_manifest_reconciliation"],
        "datasets_summary": [
            {
                "dataset_id": d["dataset_id"],
                "display_name": d["display_name"],
                "license": d["license"],
                "commercial_use_allowed": d["commercial_use_allowed"],
                "access_status": d["access_status"],
                "age_group": d["age_group"],
                "language_dialect": d["language_dialect"],
                "local_phase0_sample_count": d["local_phase0_sample_count"],
                "known_contamination_risks": d["known_contamination_risks"],
            }
            for d in dataset_reg["datasets"]
        ],
        "leakage_audit_summary": {
            "manifest_records_scanned": manifest_leakage["manifest_records_scanned"],
            "audio_files_hashed": manifest_leakage["leakage_audit"]["audio_files_hashed"],
            "has_critical_leakage": manifest_leakage["leakage_audit"]["has_critical_leakage"],
            "counts": manifest_leakage["leakage_audit"]["counts"],
            "historical_split_warning": manifest_leakage["historical_split_warning"],
        },
        "contamination_highlights": [
            row
            for row in matrix_rows
            if row["contamination_status"] in ("DIRECT_OVERLAP", "MODEL_UNAVAILABLE")
        ][:30],
        "anti_cheating_summary": {
            "total_tests": anti_cheating["total_tests"],
            "passed_count": anti_cheating["passed_count"],
            "failed_count": anti_cheating["failed_count"],
            "all_passed": anti_cheating["all_passed"],
            "tests": anti_cheating["tests"],
        },
    }

    summary_file = out_dir / "phase0_summary.json"
    summary_file.write_text(json.dumps(sanitized_summary, indent=2, ensure_ascii=False), encoding="utf-8")
    return summary_file


def run_all() -> dict[str, Any]:
    cfg = YasserWorkspaceConfig()
    workspace_info = ensure_workspace(cfg)
    model_reg = write_model_registry(MODEL_REGISTRY_PATH)
    dataset_reg = write_dataset_registry(DATASET_REGISTRY_PATH)
    matrix_rows = write_contamination_matrix(CONTAMINATION_MATRIX_PATH)
    manifest_leakage = audit_existing_project_manifests(cfg)
    anti_cheating = run_all_15_anti_cheating_tests()

    full_summary = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "workspace_setup": workspace_info,
        "model_registry_path": str(MODEL_REGISTRY_PATH),
        "dataset_registry_path": str(DATASET_REGISTRY_PATH),
        "contamination_matrix_path": str(CONTAMINATION_MATRIX_PATH),
        "legacy_manifest_reconciliation": model_reg["legacy_manifest_reconciliation"],
        "manifest_leakage_audit": manifest_leakage,
        "anti_cheating_suite": anti_cheating,
    }
    phase0_summary_path = PHASE0_DIR / "phase0_audit_summary.json"
    phase0_summary_path.write_text(json.dumps(full_summary, indent=2, ensure_ascii=False), encoding="utf-8")

    # Copy audit summary to D:\YasserML\reports as well
    (cfg.reports_dir / "phase0_audit_summary.json").write_text(
        json.dumps(full_summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    export_sanitized_flutter_governance_bundle(
        cfg=cfg,
        workspace_info=workspace_info,
        model_reg=model_reg,
        dataset_reg=dataset_reg,
        matrix_rows=matrix_rows,
        manifest_leakage=manifest_leakage,
        anti_cheating=anti_cheating,
    )
    return full_summary


if __name__ == "__main__":
    summary = run_all()
    print(json.dumps({
        "c_drive_free_gb": summary["workspace_setup"]["storage_report"]["drives"]["C"].get("free_gb"),
        "d_drive_free_gb": summary["workspace_setup"]["storage_report"]["drives"]["D"].get("free_gb"),
        "legacy_manifest_issues": summary["legacy_manifest_reconciliation"]["issue_count"],
        "scanned_clips": summary["manifest_leakage_audit"]["manifest_records_scanned"],
        "hashed_wavs": summary["manifest_leakage_audit"]["leakage_audit"]["audio_files_hashed"],
        "leakage_counts": summary["manifest_leakage_audit"]["leakage_audit"]["counts"],
        "anti_cheating": f"{summary['anti_cheating_suite']['passed_count']}/{summary['anti_cheating_suite']['total_tests']}",
    }, indent=2))
