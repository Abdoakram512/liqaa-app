"""Phase 0 Blind Test Protection: strict artifact hashes, speaker-identity locks, vault separation & guards."""

from __future__ import annotations

import hashlib
import inspect
import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from .leakage_engine import is_non_speech_record
from .workspace_config import REPO_ROOT


FORBIDDEN_HINT_PARAM_NAMES = {
    "target_word",
    "targetword",
    "expected_phonemes",
    "expected_word",
    "label",
    "labels",
    "ground_truth",
    "expected_outcome",
    "target_phoneme",
    "target_ipa",
    "hint",
    "oracle",
}

DEFAULT_MODEL_ARTIFACTS = [
    "AI_MODELS_MANIFEST.json",
    "assets/ai_models/silero/silero_vad.onnx",
    "assets/ai_models/gtcrn/gtcrn_simple.onnx",
    "assets/ai_models/wav2vec2_espeak/model_q4f16.onnx",
    "assets/ai_models/wav2vec2_espeak/vocab.json",
    "assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx",
    "assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx",
    "assets/ai_models/whisper_tiny/tiny-tokens.txt",
]

DEFAULT_PREPROCESSING_CODE = [
    "lib/core/ai/audio_preprocessor.dart",
    "lib/core/ai/phoneme_recognition_engine.dart",
    "lib/core/ai/pronunciation_evaluator.dart",
    "lib/core/ai/pronunciation_repository.dart",
    "benchmarks/phase0/leakage_engine.py",
    "benchmarks/phase0/metrics_engine.py",
]


class BlindAuthorizationError(RuntimeError):
    """Raised whenever blind holdout preconditions, freeze locks, or leakage guards fail."""


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_json_sha256(obj: Any) -> str:
    payload = json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def compute_disk_model_hashes(
    repo_root: Path = REPO_ROOT,
    artifact_rel_paths: list[str] | None = None,
) -> dict[str, str]:
    """Hash actual bundled model weights & manifest bytes from disk (fails if missing)."""
    paths = artifact_rel_paths or DEFAULT_MODEL_ARTIFACTS
    hashes: dict[str, str] = {}
    for rel in paths:
        p = repo_root / rel
        if not p.exists() or not p.is_file():
            raise BlindAuthorizationError(f"MISSING_MODEL_ARTIFACT_ON_DISK: '{rel}' cannot be locked/verified.")
        hashes[rel] = _sha256_file(p)
    return hashes


def compute_disk_preprocessing_hashes(
    repo_root: Path = REPO_ROOT,
    code_rel_paths: list[str] | None = None,
) -> dict[str, str]:
    """Hash actual preprocessing and evaluation code files from disk."""
    paths = code_rel_paths or DEFAULT_PREPROCESSING_CODE
    hashes: dict[str, str] = {}
    for rel in paths:
        p = repo_root / rel
        if not p.exists() or not p.is_file():
            raise BlindAuthorizationError(f"MISSING_PREPROCESSING_CODE_ON_DISK: '{rel}' missing.")
        hashes[rel] = _sha256_file(p)
    return hashes


def verify_blind_inference_signature(fn: Callable[..., Any]) -> None:
    """Reject any recognizer callable whose signature accepts target-word/ground-truth hints."""
    sig = inspect.signature(fn)
    for param_name in sig.parameters:
        if param_name.lower() in FORBIDDEN_HINT_PARAM_NAMES:
            raise BlindAuthorizationError(
                f"CHEATING_SIGNATURE_DETECTED: Inference entrypoint '{fn.__name__}' "
                f"exposes forbidden ground-truth parameter '{param_name}'."
            )


@dataclass
class BlindFreezeLock:
    """Immutable cryptographic lock governing Stage B blind evaluation."""

    freeze_version: str
    created_utc: str
    stage_a_manifest_sha256: str
    stage_b_inputs_sha256: str
    stage_b_labels_sha256: str
    stage_b_audio_files_sha256: str
    model_revision_sha256: str
    thresholds_sha256: str
    preprocessing_sha256: str
    stage_b_sample_count: int
    speaker_disjoint_verified: bool
    unknown_speaker_count: int = 0
    tracked_model_paths: list[str] = field(default_factory=list)
    tracked_code_paths: list[str] = field(default_factory=list)

    def overall_lock_sha256(self) -> str:
        return canonical_json_sha256(self.to_dict())

    def to_dict(self) -> dict[str, Any]:
        return {
            "freeze_version": self.freeze_version,
            "created_utc": self.created_utc,
            "stage_a_manifest_sha256": self.stage_a_manifest_sha256,
            "stage_b_inputs_sha256": self.stage_b_inputs_sha256,
            "stage_b_labels_sha256": self.stage_b_labels_sha256,
            "stage_b_audio_files_sha256": self.stage_b_audio_files_sha256,
            "model_revision_sha256": self.model_revision_sha256,
            "thresholds_sha256": self.thresholds_sha256,
            "preprocessing_sha256": self.preprocessing_sha256,
            "stage_b_sample_count": self.stage_b_sample_count,
            "speaker_disjoint_verified": self.speaker_disjoint_verified,
            "unknown_speaker_count": self.unknown_speaker_count,
            "tracked_model_paths": self.tracked_model_paths,
            "tracked_code_paths": self.tracked_code_paths,
        }


def strip_blind_labels(stage_b_records: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    """Separate blind audio inputs from ground-truth labels so inference never sees targets."""
    input_rows: list[dict[str, Any]] = []
    label_vault: dict[str, dict[str, Any]] = {}
    label_keys = {
        "target_word",
        "actual_spoken_word",
        "reference_ipa",
        "expected_phonemes",
        "actual_speech_present",
        "pronunciation_error_category",
        "target_phoneme",
        "actual_pronounced_phoneme",
        "expected_outcome",
        "ground_truth_reliability",
    }
    for rec in stage_b_records:
        if rec.get("audio_type") == "controlled_synthetic" or rec.get("is_synthetic") is True:
            raise BlindAuthorizationError(
                f"STAGE_B_SYNTHETIC_FORBIDDEN: Synthetic sample '{rec.get('sample_id')}' blocked from Stage B Blind Holdout."
            )
        sid = rec["sample_id"]
        clean_input = {k: v for k, v in rec.items() if k not in label_keys}
        clean_input["blind_labels_stripped"] = True
        input_rows.append(clean_input)
        label_vault[sid] = {k: rec[k] for k in label_keys if k in rec}
    return input_rows, label_vault


def _compute_stage_b_audio_hashes(stage_b_inputs: list[dict[str, Any]], audio_root: Path | None) -> str:
    if audio_root is None:
        return "NO_AUDIO_ROOT_PROVIDED"
    audio_map: dict[str, str] = {}
    for rec in stage_b_inputs:
        rel = rec.get("file_path") or rec.get("path") or ""
        if not rel:
            continue
        p = Path(rel) if Path(rel).is_absolute() else (audio_root / rel)
        if not p.exists() or not p.is_file():
            raise BlindAuthorizationError(f"STAGE_B_AUDIO_MISSING: '{p}' for '{rec.get('sample_id')}' missing on disk.")
        audio_map[rec["sample_id"]] = _sha256_file(p)
    return canonical_json_sha256(audio_map)


def create_freeze_lock(
    stage_a_records: list[dict[str, Any]],
    stage_b_inputs: list[dict[str, Any]],
    stage_b_labels: dict[str, dict[str, Any]],
    model_revision_info: dict[str, Any] | None = None,
    thresholds_config: dict[str, Any] | None = None,
    preprocessing_config: dict[str, Any] | None = None,
    freeze_version: str = "phase0-freeze-v2",
    repo_root: Path = REPO_ROOT,
    audio_root: Path | None = None,
    verify_disk_system: bool = True,
) -> BlindFreezeLock:
    """Create strict Stage B freeze lock; rejects empty sets & unknown speech speakers."""
    if not stage_b_inputs:
        raise BlindAuthorizationError("EMPTY_BLIND_DATASET: Cannot freeze or validate an empty Stage B split.")

    unknown_speech_ids: list[str] = []
    speakers_a: set[str] = set()
    speakers_b: set[str] = set()

    for r in stage_a_records:
        spk = str(r.get("speaker_id", "")).strip()
        if not spk or spk.lower() in ("none", "n/a", "unknown"):
            if not is_non_speech_record(r):
                unknown_speech_ids.append(str(r.get("sample_id", "?")))
        else:
            speakers_a.add(spk)

    for r in stage_b_inputs:
        spk = str(r.get("speaker_id", "")).strip()
        if not spk or spk.lower() in ("none", "n/a", "unknown"):
            if not is_non_speech_record(r):
                unknown_speech_ids.append(str(r.get("sample_id", "?")))
        else:
            speakers_b.add(spk)

    if unknown_speech_ids:
        raise BlindAuthorizationError(
            "UNKNOWN_SPEAKER_IDENTITY_REJECTED: Unknown/missing speaker_id on speech records "
            f"{unknown_speech_ids[:5]} cannot serve as proof of speaker independence."
        )

    overlap = speakers_a & speakers_b
    if overlap:
        raise BlindAuthorizationError(f"Speaker overlap between Stage A and Stage B blocks freeze creation: {sorted(overlap)}")

    tracked_models: list[str] = []
    tracked_code: list[str] = []
    if verify_disk_system:
        disk_models = compute_disk_model_hashes(repo_root)
        disk_code = compute_disk_preprocessing_hashes(repo_root)
        tracked_models = sorted(disk_models.keys())
        tracked_code = sorted(disk_code.keys())
        effective_models = {"disk_artifacts": disk_models, "extra": model_revision_info or {}}
        effective_preproc = {"disk_code": disk_code, "params": preprocessing_config or {}}
    else:
        effective_models = model_revision_info or {}
        effective_preproc = preprocessing_config or {}

    audio_sha = _compute_stage_b_audio_hashes(stage_b_inputs, audio_root)

    return BlindFreezeLock(
        freeze_version=freeze_version,
        created_utc=datetime.now(timezone.utc).isoformat(),
        stage_a_manifest_sha256=canonical_json_sha256(stage_a_records),
        stage_b_inputs_sha256=canonical_json_sha256(stage_b_inputs),
        stage_b_labels_sha256=canonical_json_sha256(stage_b_labels),
        stage_b_audio_files_sha256=audio_sha,
        model_revision_sha256=canonical_json_sha256(effective_models),
        thresholds_sha256=canonical_json_sha256(thresholds_config or {}),
        preprocessing_sha256=canonical_json_sha256(effective_preproc),
        stage_b_sample_count=len(stage_b_inputs),
        speaker_disjoint_verified=True,
        unknown_speaker_count=0,
        tracked_model_paths=tracked_models,
        tracked_code_paths=tracked_code,
    )


def authorize_blind_execution(
    lock: BlindFreezeLock,
    stage_b_inputs: list[dict[str, Any]],
    model_revision_info: dict[str, Any] | None = None,
    thresholds_config: dict[str, Any] | None = None,
    preprocessing_config: dict[str, Any] | None = None,
    inference_fn: Callable[..., Any] | None = None,
    repo_root: Path = REPO_ROOT,
    audio_root: Path | None = None,
    verify_disk_system: bool = True,
) -> dict[str, Any]:
    """Enforce zero drift across inputs, audio bytes, thresholds, code, real disk model hashes & signature."""
    if lock.stage_b_sample_count <= 0 or not stage_b_inputs:
        raise BlindAuthorizationError("EMPTY_BLIND_DATASET: Empty Stage B holdout cannot be authorized.")
    if not lock.speaker_disjoint_verified or lock.unknown_speaker_count > 0:
        raise BlindAuthorizationError("Blind freeze lock missing verified speaker disjointness.")
    if canonical_json_sha256(stage_b_inputs) != lock.stage_b_inputs_sha256:
        raise BlindAuthorizationError("BLIND_TAMPER_DETECTED: Stage B input manifest hash mismatch.")
    if canonical_json_sha256(thresholds_config or {}) != lock.thresholds_sha256:
        raise BlindAuthorizationError("THRESHOLD_DRIFT_DETECTED: Cannot alter thresholds during Stage B blind execution.")

    if verify_disk_system:
        disk_models = compute_disk_model_hashes(repo_root, lock.tracked_model_paths or None)
        disk_code = compute_disk_preprocessing_hashes(repo_root, lock.tracked_code_paths or None)
        effective_models = {"disk_artifacts": disk_models, "extra": model_revision_info or {}}
        effective_preproc = {"disk_code": disk_code, "params": preprocessing_config or {}}
    else:
        effective_models = model_revision_info or {}
        effective_preproc = preprocessing_config or {}

    if canonical_json_sha256(effective_preproc) != lock.preprocessing_sha256:
        raise BlindAuthorizationError("PREPROCESSING_DRIFT_DETECTED: Preprocessing code or config changed after freeze.")
    if canonical_json_sha256(effective_models) != lock.model_revision_sha256:
        raise BlindAuthorizationError("MODEL_ARTIFACT_TAMPER_OR_MISMATCH: Disk model artifacts or manifest changed after freeze.")

    if lock.stage_b_audio_files_sha256 != "NO_AUDIO_ROOT_PROVIDED" or audio_root is not None:
        if _compute_stage_b_audio_hashes(stage_b_inputs, audio_root) != lock.stage_b_audio_files_sha256:
            raise BlindAuthorizationError("BLIND_AUDIO_MODIFIED_ON_DISK: Stage B WAV file bytes altered after freeze.")

    for rec in stage_b_inputs:
        for forbidden in ("target_word", "expected_outcome", "actual_pronounced_phoneme", "reference_ipa"):
            if forbidden in rec:
                raise BlindAuthorizationError(
                    f"BLIND_LABEL_LEAK: Field '{forbidden}' present in blind inference input '{rec.get('sample_id')}'."
                )
    if inference_fn is not None:
        verify_blind_inference_signature(inference_fn)

    return {
        "authorized": True,
        "freeze_version": lock.freeze_version,
        "lock_sha256": lock.overall_lock_sha256(),
        "verified_utc": datetime.now(timezone.utc).isoformat(),
    }


def write_blind_package(
    vault_dir: Path,
    repo_manifest_dir: Path,
    stage_a_records: list[dict[str, Any]],
    stage_b_records: list[dict[str, Any]],
    model_revision_info: dict[str, Any] | None = None,
    thresholds_config: dict[str, Any] | None = None,
    preprocessing_config: dict[str, Any] | None = None,
    repo_root: Path = REPO_ROOT,
    audio_root: Path | None = None,
) -> BlindFreezeLock:
    """Persist public blind inputs + freeze lock cleanly while keeping blind labels ONLY in external vault."""
    vault_dir.mkdir(parents=True, exist_ok=True)
    repo_manifest_dir.mkdir(parents=True, exist_ok=True)

    inputs, labels = strip_blind_labels(stage_b_records)
    lock = create_freeze_lock(
        stage_a_records=stage_a_records,
        stage_b_inputs=inputs,
        stage_b_labels=labels,
        model_revision_info=model_revision_info,
        thresholds_config=thresholds_config,
        preprocessing_config=preprocessing_config,
        repo_root=repo_root,
        audio_root=audio_root,
    )

    (repo_manifest_dir / "stage_b_inputs_blind.jsonl").write_text(
        "\n".join(json.dumps(r, ensure_ascii=False) for r in inputs) + ("\n" if inputs else ""),
        encoding="utf-8",
    )
    (repo_manifest_dir / "stage_b_freeze_lock.json").write_text(
        json.dumps(lock.to_dict(), indent=2),
        encoding="utf-8",
    )
    (vault_dir / "stage_b_labels_VAULT_ONLY.json").write_text(
        json.dumps(labels, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return lock
