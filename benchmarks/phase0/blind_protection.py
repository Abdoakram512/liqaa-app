"""Phase 0.1 Blind Test Protection: dynamic registry locks, strict audio & path validation, and GT integrity."""

from __future__ import annotations

import hashlib
import inspect
import json
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from importlib import metadata as importlib_metadata
from pathlib import Path
from typing import Any, Callable

from .leakage_engine import is_non_speech_record
from .workspace_config import PHASE0_DIR, REPO_ROOT

ALLOWED_BLIND_INPUT_FIELDS = {
    "sample_id",
    "file_path",
    "split",
    "dataset_id",
    "speaker_id",
    "session_id",
    "sample_rate",
    "duration_ms",
    "audio_type",
    "language_dialect",
    "age_group",
    "blind_labels_stripped",
}

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

FORBIDDEN_PATH_LABEL_TOKENS = (
    "correct_",
    "error_",
    "fronting",
    "lisp",
    "lateralization",
    "mispronounced",
    "pass_",
    "fail_",
    "kora",
    "samaka",
    "arnab",
)

DEFAULT_PIPELINE_CODE_PATHS = [
    "lib/core/ai/audio_preprocessor.dart",
    "lib/core/ai/phoneme_recognition_engine.dart",
    "lib/core/ai/pronunciation_evaluator.dart",
    "lib/core/ai/pronunciation_repository.dart",
    "lib/core/ai/speech_to_text_engine.dart",
    "assets/pronunciation/egyptian_arabic_dictionary.json",
    "benchmarks/phase0/leakage_engine.py",
    "benchmarks/phase0/metrics_engine.py",
]

# Retained alias for test backwards-compatibility with dynamic registry resolution preferred.
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
DEFAULT_PREPROCESSING_CODE = DEFAULT_PIPELINE_CODE_PATHS


class BlindAuthorizationError(RuntimeError):
    """Raised whenever blind holdout preconditions, freeze locks, path checks, or GT integrity fail."""


def _is_git_lfs_pointer(data_prefix: bytes) -> bool:
    return data_prefix.startswith(b"version https://git-lfs.github.com/spec/v1")


def _sha256_file_real(path: Path) -> str:
    """Hash file bytes and fail loudly if file is missing or only an unresolved Git LFS pointer."""
    with open(path, "rb") as f:
        head = f.read(128)
        if _is_git_lfs_pointer(head):
            raise BlindAuthorizationError(
                f"GIT_LFS_POINTER_NOT_WEIGHTS: '{path}' is an unresolved Git LFS pointer stub."
            )
        h = hashlib.sha256(head)
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_json_sha256(obj: Any) -> str:
    payload = json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def collect_runtime_dependency_versions() -> dict[str, str]:
    """Capture installed Python & Dart/Flutter package versions relevant to AI preprocessing/eval."""
    versions: dict[str, str] = {}
    for pkg in ("numpy", "scipy", "onnxruntime", "huggingface_hub"):
        try:
            versions[f"py:{pkg}"] = importlib_metadata.version(pkg)
        except importlib_metadata.PackageNotFoundError:
            pass
    pubspec_lock = REPO_ROOT / "pubspec.lock"
    if pubspec_lock.exists():
        txt = pubspec_lock.read_text(encoding="utf-8", errors="ignore")
        for dart_pkg in ("sherpa_onnx", "record", "audioplayers"):
            m = re.search(rf"^\s*{dart_pkg}:\s*$.*?^\s*version:\s*\"([^\"]+)\"", txt, re.MULTILINE | re.DOTALL)
            if m:
                versions[f"dart:{dart_pkg}"] = m.group(1)
    return versions


def resolve_dynamic_model_artifacts(
    selected_model_ids: list[str] | None = None,
    repo_root: Path = REPO_ROOT,
    registry_path: Path | None = None,
) -> list[str]:
    """Derive model artifact paths dynamically from MODEL_REGISTRY.json (future-extensible)."""
    reg_file = registry_path or (repo_root / "benchmarks" / "phase0" / "MODEL_REGISTRY.json")
    if not reg_file.exists():
        return list(DEFAULT_MODEL_ARTIFACTS)

    reg = json.loads(reg_file.read_text(encoding="utf-8"))
    chosen = set(selected_model_ids) if selected_model_ids else None
    paths: set[str] = {"AI_MODELS_MANIFEST.json"}

    for m in reg.get("models", []):
        mid = m.get("model_id", "")
        if chosen is not None and mid not in chosen:
            continue
        if chosen is None and m.get("availability_status") != "LOCAL_BUNDLED_VERIFIED":
            continue
        for fmeta in m.get("artifact_files", []):
            rel = fmeta.get("path", "")
            if rel:
                paths.add(rel)

    return sorted(paths)


def compute_disk_model_hashes(
    repo_root: Path = REPO_ROOT,
    artifact_rel_paths: list[str] | None = None,
    selected_model_ids: list[str] | None = None,
) -> dict[str, str]:
    """Hash actual non-LFS model weights, vocabularies & manifest from disk."""
    paths = artifact_rel_paths or resolve_dynamic_model_artifacts(
        selected_model_ids=selected_model_ids, repo_root=repo_root
    )
    hashes: dict[str, str] = {}
    for rel in paths:
        p = repo_root / rel
        if not p.exists() or not p.is_file():
            raise BlindAuthorizationError(f"MISSING_MODEL_ARTIFACT_ON_DISK: '{rel}' cannot be locked/verified.")
        hashes[rel] = _sha256_file_real(p)
    return hashes


def compute_disk_preprocessing_hashes(
    repo_root: Path = REPO_ROOT,
    code_rel_paths: list[str] | None = None,
) -> dict[str, str]:
    """Hash preprocessing code, adapter code, pronunciation dictionary & evaluation modules."""
    paths = code_rel_paths or DEFAULT_PIPELINE_CODE_PATHS
    hashes: dict[str, str] = {}
    for rel in paths:
        p = repo_root / rel
        if not p.exists() or not p.is_file():
            raise BlindAuthorizationError(f"MISSING_PIPELINE_CODE_ON_DISK: '{rel}' missing.")
        hashes[rel] = _sha256_file_real(p)
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


def _validate_safe_audio_path(rel_path: str, audio_root: Path, sample_id: str, check_label_tokens: bool = True) -> Path:
    if not rel_path or "\x00" in rel_path:
        raise BlindAuthorizationError(f"MISSING_OR_UNSAFE_PATH: Sample '{sample_id}' lacks a valid recording path.")
    raw_p = Path(rel_path)
    if raw_p.is_absolute() or ".." in raw_p.parts:
        raise BlindAuthorizationError(
            f"UNSAFE_AUDIO_PATH_REJECTED: Sample '{sample_id}' path '{rel_path}' must be relative inside audio_root without traversal."
        )
    resolved_root = audio_root.resolve()
    resolved_file = (resolved_root / raw_p).resolve()
    try:
        resolved_file.relative_to(resolved_root)
    except ValueError as exc:
        raise BlindAuthorizationError(
            f"PATH_ESCAPE_REJECTED: Sample '{sample_id}' escapes audio_root ({rel_path})."
        ) from exc

    if check_label_tokens:
        lower_rel = rel_path.lower()
        for tok in FORBIDDEN_PATH_LABEL_TOKENS:
            if tok in lower_rel:
                raise BlindAuthorizationError(
                    f"BLIND_FILENAME_LABEL_LEAK: Audio filename/path '{rel_path}' leaks ground-truth token '{tok}'."
                )

    if not resolved_file.exists() or not resolved_file.is_file():
        raise BlindAuthorizationError(f"STAGE_B_AUDIO_MISSING: '{resolved_file}' for '{sample_id}' missing on disk.")
    if resolved_file.stat().st_size <= 44:
        raise BlindAuthorizationError(f"EMPTY_OR_CORRUPT_BLIND_AUDIO: '{resolved_file}' <= 44 bytes.")
    return resolved_file


def strip_blind_labels(
    stage_b_records: list[dict[str, Any]],
    strict_filename_guard: bool = False,
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    """Allowlist ONLY target-independent audio metadata fields into blind inputs; place labels in vault."""
    input_rows: list[dict[str, Any]] = []
    label_vault: dict[str, dict[str, Any]] = {}
    seen_ids: set[str] = set()

    for rec in stage_b_records:
        if rec.get("audio_type") == "controlled_synthetic" or rec.get("is_synthetic") is True:
            raise BlindAuthorizationError(
                f"STAGE_B_SYNTHETIC_FORBIDDEN: Synthetic sample '{rec.get('sample_id')}' blocked from Stage B Blind Holdout."
            )
        sid = str(rec.get("sample_id", "")).strip()
        if not sid:
            raise BlindAuthorizationError("MISSING_SAMPLE_ID: Stage B record without sample_id.")
        if sid in seen_ids:
            raise BlindAuthorizationError(f"DUPLICATE_SAMPLE_ID: Duplicate sample_id '{sid}' in Stage B.")
        seen_ids.add(sid)

        if strict_filename_guard and rec.get("file_path"):
            lower_p = str(rec["file_path"]).lower()
            for tok in FORBIDDEN_PATH_LABEL_TOKENS:
                if tok in lower_p:
                    raise BlindAuthorizationError(
                        f"BLIND_FILENAME_LABEL_LEAK: Path '{rec['file_path']}' embeds target/outcome token '{tok}'."
                    )

        clean_input = {k: v for k, v in rec.items() if k in ALLOWED_BLIND_INPUT_FIELDS}
        clean_input["blind_labels_stripped"] = True
        input_rows.append(clean_input)

        labels_payload = {k: v for k, v in rec.items() if k not in ALLOWED_BLIND_INPUT_FIELDS}
        label_vault[sid] = labels_payload

    return input_rows, label_vault


@dataclass
class BlindFreezeLock:
    """Immutable cryptographic lock governing Stage B blind evaluation."""

    freeze_version: str
    created_utc: str
    stage_a_manifest_sha256: str
    stage_b_inputs_sha256: str
    stage_b_labels_sha256: str
    stage_b_audio_files_sha256: str
    stage_b_per_sample_hashes: dict[str, str]
    model_revision_sha256: str
    thresholds_sha256: str
    preprocessing_sha256: str
    dependency_versions_sha256: str
    stage_b_sample_count: int
    speaker_disjoint_verified: bool
    unknown_speaker_count: int = 0
    selected_model_ids: list[str] = field(default_factory=list)
    tracked_model_paths: list[str] = field(default_factory=list)
    tracked_code_paths: list[str] = field(default_factory=list)
    strict_audio_verified: bool = True

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
            "stage_b_per_sample_hashes": self.stage_b_per_sample_hashes,
            "model_revision_sha256": self.model_revision_sha256,
            "thresholds_sha256": self.thresholds_sha256,
            "preprocessing_sha256": self.preprocessing_sha256,
            "dependency_versions_sha256": self.dependency_versions_sha256,
            "stage_b_sample_count": self.stage_b_sample_count,
            "speaker_disjoint_verified": self.speaker_disjoint_verified,
            "unknown_speaker_count": self.unknown_speaker_count,
            "selected_model_ids": self.selected_model_ids,
            "tracked_model_paths": self.tracked_model_paths,
            "tracked_code_paths": self.tracked_code_paths,
            "strict_audio_verified": self.strict_audio_verified,
        }


def _compute_stage_b_audio_hashes(
    stage_b_inputs: list[dict[str, Any]],
    audio_root: Path | None,
    *,
    strict_filename_guard: bool = True,
) -> tuple[str, dict[str, str]]:
    if audio_root is None:
        raise BlindAuthorizationError("MISSING_AUDIO_ROOT: Strict blind mode requires valid audio_root directory.")
    if not audio_root.exists() or not audio_root.is_dir():
        raise BlindAuthorizationError(f"INVALID_AUDIO_ROOT: '{audio_root}' is not an existing directory.")

    audio_map: dict[str, str] = {}
    seen_ids: set[str] = set()
    for rec in stage_b_inputs:
        sid = str(rec.get("sample_id", "")).strip()
        if not sid or sid in seen_ids:
            raise BlindAuthorizationError(f"INVALID_OR_DUPLICATE_SAMPLE_ID: '{sid}'.")
        seen_ids.add(sid)

        rel = str(rec.get("file_path") or "").strip()
        resolved_file = _validate_safe_audio_path(
            rel, audio_root, sid, check_label_tokens=strict_filename_guard
        )
        audio_map[sid] = _sha256_file_real(resolved_file)

    return canonical_json_sha256(audio_map), audio_map


def create_freeze_lock(
    stage_a_records: list[dict[str, Any]],
    stage_b_inputs: list[dict[str, Any]],
    stage_b_labels: dict[str, dict[str, Any]],
    model_revision_info: dict[str, Any] | None = None,
    thresholds_config: dict[str, Any] | None = None,
    preprocessing_config: dict[str, Any] | None = None,
    freeze_version: str = "phase0.1-freeze-v3",
    repo_root: Path = REPO_ROOT,
    audio_root: Path | None = None,
    selected_model_ids: list[str] | None = None,
    verify_disk_system: bool = True,
    strict_filename_guard: bool = True,
) -> BlindFreezeLock:
    """Create strict dynamic Stage B freeze lock; rejects empty splits, unsafe paths, missing files & unknown speakers."""
    if not stage_b_inputs:
        raise BlindAuthorizationError("EMPTY_BLIND_DATASET: Cannot freeze or validate an empty Stage B split.")

    # Verify exact 1:1 ground-truth correspondence before freezing
    input_ids = [r.get("sample_id") for r in stage_b_inputs]
    if len(set(input_ids)) != len(input_ids):
        raise BlindAuthorizationError("DUPLICATE_SAMPLE_ID: Duplicate sample_id entries in Stage B inputs.")
    if set(input_ids) != set(stage_b_labels.keys()):
        raise BlindAuthorizationError(
            "GROUND_TRUTH_CORRESPONDENCE_ERROR: Stage B inputs and Stage B labels do not match 1:1."
        )

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
        disk_models = compute_disk_model_hashes(
            repo_root, selected_model_ids=selected_model_ids
        )
        disk_code = compute_disk_preprocessing_hashes(repo_root)
        tracked_models = sorted(disk_models.keys())
        tracked_code = sorted(disk_code.keys())
        effective_models = {"disk_artifacts": disk_models, "extra": model_revision_info or {}}
        effective_preproc = {"disk_code": disk_code, "params": preprocessing_config or {}}
    else:
        effective_models = model_revision_info or {}
        effective_preproc = preprocessing_config or {}

    audio_sha, per_sample_hashes = _compute_stage_b_audio_hashes(
        stage_b_inputs, audio_root, strict_filename_guard=strict_filename_guard
    )
    dep_versions = collect_runtime_dependency_versions()

    return BlindFreezeLock(
        freeze_version=freeze_version,
        created_utc=datetime.now(timezone.utc).isoformat(),
        stage_a_manifest_sha256=canonical_json_sha256(stage_a_records),
        stage_b_inputs_sha256=canonical_json_sha256(stage_b_inputs),
        stage_b_labels_sha256=canonical_json_sha256(stage_b_labels),
        stage_b_audio_files_sha256=audio_sha,
        stage_b_per_sample_hashes=per_sample_hashes,
        model_revision_sha256=canonical_json_sha256(effective_models),
        thresholds_sha256=canonical_json_sha256(thresholds_config or {}),
        preprocessing_sha256=canonical_json_sha256(effective_preproc),
        dependency_versions_sha256=canonical_json_sha256(dep_versions),
        stage_b_sample_count=len(stage_b_inputs),
        speaker_disjoint_verified=True,
        unknown_speaker_count=0,
        selected_model_ids=selected_model_ids or [],
        tracked_model_paths=tracked_models,
        tracked_code_paths=tracked_code,
        strict_audio_verified=True,
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
    strict_filename_guard: bool = True,
) -> dict[str, Any]:
    """Strict authorization gate checking allowlisted inputs, real WAV bytes, models, code & thresholds."""
    if lock.stage_b_sample_count <= 0 or not stage_b_inputs:
        raise BlindAuthorizationError("EMPTY_BLIND_DATASET: Empty Stage B holdout cannot be authorized.")
    if not lock.speaker_disjoint_verified or lock.unknown_speaker_count > 0:
        raise BlindAuthorizationError("Blind freeze lock missing verified speaker disjointness.")
    if canonical_json_sha256(stage_b_inputs) != lock.stage_b_inputs_sha256:
        raise BlindAuthorizationError("BLIND_TAMPER_DETECTED: Stage B input manifest hash mismatch.")
    if canonical_json_sha256(thresholds_config or {}) != lock.thresholds_sha256:
        raise BlindAuthorizationError("THRESHOLD_DRIFT_DETECTED: Cannot alter thresholds during Stage B blind execution.")
    if canonical_json_sha256(collect_runtime_dependency_versions()) != lock.dependency_versions_sha256:
        raise BlindAuthorizationError("DEPENDENCY_DRIFT_DETECTED: Runtime package versions changed after freeze.")

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

    audio_sha, per_sample = _compute_stage_b_audio_hashes(
        stage_b_inputs, audio_root, strict_filename_guard=strict_filename_guard
    )
    if audio_sha != lock.stage_b_audio_files_sha256 or per_sample != lock.stage_b_per_sample_hashes:
        raise BlindAuthorizationError("BLIND_AUDIO_MODIFIED_ON_DISK: Stage B WAV file bytes altered after freeze.")

    for rec in stage_b_inputs:
        extra = set(rec.keys()) - ALLOWED_BLIND_INPUT_FIELDS
        if extra:
            raise BlindAuthorizationError(
                f"BLIND_ALLOWLIST_VIOLATION: Non-allowlisted metadata keys {sorted(extra)} present in '{rec.get('sample_id')}'."
            )

    if inference_fn is not None:
        verify_blind_inference_signature(inference_fn)

    return {
        "authorized": True,
        "freeze_version": lock.freeze_version,
        "lock_sha256": lock.overall_lock_sha256(),
        "verified_samples": len(stage_b_inputs),
        "verified_utc": datetime.now(timezone.utc).isoformat(),
    }


def verify_and_prepare_blind_scoring(
    lock: BlindFreezeLock,
    stage_a_records: list[dict[str, Any]],
    stage_b_inputs: list[dict[str, Any]],
    stage_b_labels: dict[str, dict[str, Any]],
    blind_predictions: list[dict[str, Any]],
) -> dict[str, Any]:
    """D3 Ground-Truth Integrity Gate before computing Stage B blind scores."""
    if canonical_json_sha256(stage_a_records) != lock.stage_a_manifest_sha256:
        raise BlindAuthorizationError("STAGE_A_MANIFEST_DRIFT: Stage A records mutated since freeze.")
    if canonical_json_sha256(stage_b_inputs) != lock.stage_b_inputs_sha256:
        raise BlindAuthorizationError("STAGE_B_INPUTS_DRIFT: Stage B inputs mutated since freeze.")
    if canonical_json_sha256(stage_b_labels) != lock.stage_b_labels_sha256:
        raise BlindAuthorizationError("GROUND_TRUTH_TAMPERED: Stage B label vault hash mismatch.")

    expected_ids = {r["sample_id"] for r in stage_b_inputs}
    if set(stage_b_labels.keys()) != expected_ids:
        raise BlindAuthorizationError("GROUND_TRUTH_INCOMPLETE: Missing or extra sample IDs in label vault.")

    pred_ids: list[str] = []
    for p in blind_predictions:
        if p.get("used_target_word_hint") is True:
            raise BlindAuthorizationError(
                f"BLIND_CONTAMINATION_DETECTED: Prediction '{p.get('sample_id')}' reports target-word hint usage."
            )
        pred_ids.append(str(p.get("sample_id", "")).strip())

    if len(pred_ids) != len(set(pred_ids)):
        raise BlindAuthorizationError("DUPLICATE_PREDICTION_IDS: Blind prediction artifact has duplicate sample IDs.")
    if set(pred_ids) != expected_ids:
        missing = sorted(expected_ids - set(pred_ids))
        extra = sorted(set(pred_ids) - expected_ids)
        raise BlindAuthorizationError(
            f"PREDICTION_CORRESPONDENCE_ERROR: missing={missing[:5]}, extra={extra[:5]}"
        )

    return {
        "integrity_verified": True,
        "predictions_sha256": canonical_json_sha256(blind_predictions),
        "sample_count": len(blind_predictions),
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
    selected_model_ids: list[str] | None = None,
) -> BlindFreezeLock:
    """Persist allowlisted blind inputs + freeze lock cleanly while keeping blind labels ONLY in external vault."""
    vault_dir.mkdir(parents=True, exist_ok=True)
    repo_manifest_dir.mkdir(parents=True, exist_ok=True)

    inputs, labels = strip_blind_labels(stage_b_records, strict_filename_guard=True)
    lock = create_freeze_lock(
        stage_a_records=stage_a_records,
        stage_b_inputs=inputs,
        stage_b_labels=labels,
        model_revision_info=model_revision_info,
        thresholds_config=thresholds_config,
        preprocessing_config=preprocessing_config,
        repo_root=repo_root,
        audio_root=audio_root,
        selected_model_ids=selected_model_ids,
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
