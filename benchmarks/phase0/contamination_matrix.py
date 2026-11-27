"""Phase 0 Model-to-Dataset Contamination Matrix generator."""

from __future__ import annotations

import csv
from pathlib import Path
from typing import Any

from .workspace_config import PHASE0_DIR

CONTAMINATION_MATRIX_PATH = PHASE0_DIR / "MODEL_DATASET_CONTAMINATION_MATRIX.csv"

MATRIX_DATASETS = [
    "asmdd",
    "abjad_kids",
    "arayoungvoices",
    "arabic_egy_cleaned",
    "egyspeak",
    "arabic_little_stt",
    "arabic_speech_corpus",
    "l2_ksu",
    "musan_noise",
    "future_egyptian_pediatric_private_collection",
]

# Status codes:
#   CLEAN_VERIFIED       = Independent architecture/domain or verified disjoint training provenance
#   DIRECT_OVERLAP       = Explicit documented training dependency between model and dataset
#   RISK_UNVERIFIED      = Model pretraining/web scrape undisclosed; cannot guarantee zero overlap
#   MODEL_UNAVAILABLE    = External/gated weights not inspectable in Phase 0
#   SELF_AUGMENT_HAZARD  = Safe ONLY if Stage B noise files are disjoint from training noise augmentation
MODEL_CONTAMINATION_MAP: dict[str, dict[str, tuple[str, str]]] = {
    "silero_vad_v4": {
        "_default": ("RISK_LOW_GATE_ONLY", "Silero pretrained speech+noise gate; zero Arabic word labels"),
        "musan_noise": ("SELF_AUGMENT_HAZARD", "Pretrained noise mix unknown; track false alarms on held-out MUSAN clips"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "gtcrn_denoiser": {
        "_default": ("CLEAN_VERIFIED", "Waveform denoiser without Arabic lexical targets"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "rnnoise_legacy_bundled": {
        "_default": ("CLEAN_VERIFIED", "Deprecated 48kHz denoiser; unused in runtime"),
    },
    "deepfilternet3": {
        "_default": ("CLEAN_VERIFIED", "DNS4/VCTK trained enhancer; zero Arabic child label memorization"),
    },
    "wav2vec2_lv60_espeak_q4f16": {
        "_default": ("CLEAN_VERIFIED", "Trained on Libri-Light + Common Voice eSpeak; warn if Common Voice Arabic added"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "zipformer_arabic_v3": {
        "_default": ("MODEL_UNAVAILABLE", "Gated repo (license:other) + missing ONNX weights; exact recipe unverified"),
    },
    "zipformer_arabic_v2": {
        "_default": ("MODEL_UNAVAILABLE", "Missing local weights; Quranic/Arabic overlap unverified"),
    },
    "mostafamaroof_wav2vec2_arabic_phoneme": {
        "_default": ("RISK_UNVERIFIED", "XLSR-53 pretrain + Arabic phoneme fine-tune"),
        "arabic_speech_corpus": ("DIRECT_OVERLAP", "CRITICAL: Explicitly tagged dataset:tunis-ai/arabic_speech_corpus on HF"),
        "asmdd": ("CLEAN_VERIFIED", "Egyptian pediatric CC0 Mendeley corpus not cited in HF model card"),
        "abjad_kids": ("CLEAN_VERIFIED", "Not cited in HF model card"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "kgnlp_allophant": {
        "_default": ("RISK_UNVERIFIED", "XLS-R multilingual phoneme/feature recognizer; verify exact Arabic CV split"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "whisper_tiny_int8": {
        "_default": ("RISK_UNVERIFIED", "OpenAI 680k-hr web audio undisclosed; child datasets unlikely but unprovable"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "whisper_large_v3_turbo": {
        "_default": ("RISK_UNVERIFIED", "OpenAI undisclosed web/pseudo-labeled audio"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "egyptalk_asr_v2": {
        "_default": ("RISK_UNVERIFIED", "Egyptian web/media FastConformer; verify overlap with arabic_egy_cleaned/EGYSpeak"),
        "arabic_egy_cleaned": ("RISK_UNVERIFIED", "Both draw from Egyptian public media/ASR pools; check acoustic similarity"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "whisper_small_egyptian_arabic": {
        "_default": ("RISK_UNVERIFIED", "Whisper Egyptian fine-tunes"),
        "arabic_egy_cleaned": ("DIRECT_OVERLAP", "CRITICAL: MAdel121/whisper-small-egyptian-arabic explicitly trained on MAdel121/arabic-egy-cleaned"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings"),
    },
    "smart_arabic_speech_therapy_scorer": {
        "_default": ("RISK_UNVERIFIED", "Requires ASR backbone (FastConformer/Whisper) + prompt phoneme aligner"),
        "asmdd": ("DIRECT_OVERLAP", "CRITICAL: HF Space MON3EMPASHA/SmartArabicSpeechTherapy bundles dataset_info/ASMDD.csv (5,298 rows; 4,235/1,059 split)"),
        "future_egyptian_pediatric_private_collection": ("CLEAN_VERIFIED", "Unseen private pediatric recordings (target-dependent scorer only)"),
    },
}


def build_contamination_matrix() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for model_id, mapping in MODEL_CONTAMINATION_MAP.items():
        default_status, default_note = mapping["_default"]
        for ds_id in MATRIX_DATASETS:
            status, note = mapping.get(ds_id, (default_status, default_note))
            allow_clean_blind = status in ("CLEAN_VERIFIED", "RISK_LOW_GATE_ONLY")
            rows.append(
                {
                    "model_id": model_id,
                    "dataset_id": ds_id,
                    "contamination_status": status,
                    "eligible_for_clean_eval": str(allow_clean_blind).lower(),
                    "evidence_and_rule": note,
                }
            )
    return rows


def write_contamination_matrix(path: Path = CONTAMINATION_MATRIX_PATH) -> list[dict[str, Any]]:
    rows = build_contamination_matrix()
    fieldnames = ["model_id", "dataset_id", "contamination_status", "eligible_for_clean_eval", "evidence_and_rule"]
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return rows


if __name__ == "__main__":
    r = write_contamination_matrix()
    print(f"Wrote {CONTAMINATION_MATRIX_PATH} with {len(r)} cells")
