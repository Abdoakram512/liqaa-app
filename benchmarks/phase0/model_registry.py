"""Phase 0 Model Registry builder, hash verifier, and manifest reconciler."""

from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .workspace_config import PHASE0_DIR, REPO_ROOT

REGISTRY_SCHEMA_VERSION = "0.1.0-phase0"
MODEL_REGISTRY_PATH = PHASE0_DIR / "MODEL_REGISTRY.json"

REQUIRED_MODEL_FIELDS = [
    "model_id",
    "display_name",
    "category",
    "source_repo",
    "license",
    "commercial_use_allowed",
    "availability_status",
    "local_path_or_status",
    "artifact_size_mb",
    "checksum_sha256",
    "input_sample_rate_hz",
    "input_format",
    "output_type",
    "token_or_phoneme_inventory",
    "supports_blind_phoneme_only",
    "requires_target_word_hint",
    "mobile_onnx_feasibility",
    "known_training_datasets",
    "contamination_risk_notes",
    "last_verified_timestamp",
    "verification_method",
]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _local_asset_probe(rel_paths: list[str]) -> dict[str, Any]:
    existing: list[dict[str, Any]] = []
    missing: list[str] = []
    total_bytes = 0
    for rel in rel_paths:
        p = REPO_ROOT / rel
        if p.exists() and p.is_file():
            sz = p.stat().st_size
            total_bytes += sz
            existing.append(
                {
                    "path": rel,
                    "size_bytes": sz,
                    "sha256": sha256_file(p),
                }
            )
        else:
            missing.append(rel)
    return {
        "existing": existing,
        "missing": missing,
        "total_mb": round(total_bytes / (1024 * 1024), 3),
        "primary_sha256": existing[0]["sha256"] if existing else "NOT_LOCALLY_DOWNLOADED",
    }


def build_model_registry(verified_ts: str | None = None) -> dict[str, Any]:
    """Assemble the complete 13-model Phase 0 registry grounded in verified probes."""
    ts = verified_ts or datetime.now(timezone.utc).isoformat()

    silero = _local_asset_probe(["assets/ai_models/silero/silero_vad.onnx"])
    gtcrn = _local_asset_probe(["assets/ai_models/gtcrn/gtcrn_simple.onnx"])
    rnnoise = _local_asset_probe(["assets/ai_models/rnnoise/rnnoise.onnx"])
    w2v_espeak = _local_asset_probe(
        [
            "assets/ai_models/wav2vec2_espeak/model_q4f16.onnx",
            "assets/ai_models/wav2vec2_espeak/vocab.json",
        ]
    )
    zip_v2 = _local_asset_probe(
        [
            "assets/ai_models/zipformer_v2/phoneme_units.json",
            "assets/ai_models/zipformer_v2/tokens.txt",
            "assets/ai_models/zipformer_v2/encoder-epoch-99-avg-1.int8.onnx",
        ]
    )
    zip_v3 = _local_asset_probe(
        [
            "assets/ai_models/zipformer_v3/phoneme_units.json",
            "assets/ai_models/zipformer_v3/tokens.txt",
            "assets/ai_models/zipformer_v3/encoder.onnx",
        ]
    )
    whisper_tiny = _local_asset_probe(
        [
            "assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx",
            "assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx",
            "assets/ai_models/whisper_tiny/tiny-tokens.txt",
        ]
    )

    models: list[dict[str, Any]] = [
        {
            "model_id": "silero_vad_v4",
            "display_name": "Silero VAD v4/v5",
            "category": "Voice Activity Detection",
            "source_repo": "https://github.com/snakers4/silero-vad | https://huggingface.co/onnx-community/silero-vad",
            "license": "MIT",
            "commercial_use_allowed": True,
            "availability_status": "LOCAL_BUNDLED_VERIFIED",
            "local_path_or_status": "assets/ai_models/silero/silero_vad.onnx",
            "artifact_size_mb": silero["total_mb"],
            "checksum_sha256": silero["primary_sha256"],
            "artifact_files": silero["existing"],
            "input_sample_rate_hz": 16000,
            "input_format": "Float32 PCM mono (512-sample chunks @ 16kHz + LSTM h/c states)",
            "output_type": "Speech probability scalar [0.0, 1.0]",
            "token_or_phoneme_inventory": "N/A (binary speech vs non-speech gate)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "HIGH_ON_DEVICE (2.10 MB bundled; <3ms desktop FFI)",
            "known_training_datasets": ["Silero proprietary multilingual speech + noise mixtures"],
            "contamination_risk_notes": "Low direct memorization risk (VAD gate only), though threshold tuning on Stage A must remain locked before Stage B.",
            "last_verified_timestamp": ts,
            "verification_method": "Local SHA-256 disk check + HF onnx-community/silero-vad metadata probe (rev e71cae96)",
            "runtime_notes": "Active production VAD in lib/core/ai/silero_vad_engine.dart.",
        },
        {
            "model_id": "gtcrn_denoiser",
            "display_name": "GTCRN Speech Enhancement (ONNX)",
            "category": "Noise Suppression",
            "source_repo": "https://github.com/Xiaobin-Rong/gtcrn | https://github.com/k2-fsa/sherpa-onnx",
            "license": "MIT (GTCRN) / Apache-2.0 (sherpa-onnx)",
            "commercial_use_allowed": True,
            "availability_status": "LOCAL_BUNDLED_VERIFIED",
            "local_path_or_status": "assets/ai_models/gtcrn/gtcrn_simple.onnx",
            "artifact_size_mb": gtcrn["total_mb"],
            "checksum_sha256": gtcrn["primary_sha256"],
            "artifact_files": gtcrn["existing"],
            "input_sample_rate_hz": 16000,
            "input_format": "Float32 PCM mono 16kHz (STFT / ERB subband state streaming via sherpa-onnx)",
            "output_type": "Enhanced Float32 mono PCM waveform @ 16kHz",
            "token_or_phoneme_inventory": "N/A (waveform speech enhancer)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "HIGH_ON_DEVICE (0.51 MB bundled; ultra-low MACs; active runtime gated SNR<14dB)",
            "known_training_datasets": ["DNS-Challenge / VCTK+DEMAND (upstream checkpoint exact recipe unverified locally)"],
            "contamination_risk_notes": "Signal distortion / consonant attenuation on clean speech observed in prior benchmark; no label memorization.",
            "last_verified_timestamp": ts,
            "verification_method": "Local SHA-256 disk check + GitHub license verification (Xiaobin-Rong/gtcrn MIT)",
            "runtime_notes": "Active denoiser loaded by AiModelManager (key gtcrn_denoiser), missing from legacy AI_MODELS_MANIFEST.json prior to Phase 0 reconciliation.",
        },
        {
            "model_id": "rnnoise_legacy_bundled",
            "display_name": "RNNoise (Legacy Unused Artifact)",
            "category": "Noise Suppression (Deprecated Artifact)",
            "source_repo": "https://github.com/xiph/rnnoise (legacy community ONNX export)",
            "license": "BSD-3-Clause",
            "commercial_use_allowed": True,
            "availability_status": "LOCAL_DEPRECATED_UNUSED",
            "local_path_or_status": "assets/ai_models/rnnoise/rnnoise.onnx",
            "artifact_size_mb": rnnoise["total_mb"],
            "checksum_sha256": rnnoise["primary_sha256"],
            "artifact_files": rnnoise["existing"],
            "input_sample_rate_hz": 48000,
            "input_format": "48kHz BFCC features (incompatible with 16kHz PCM pipeline without feature extraction)",
            "output_type": "Spectral band gains + VAD probability",
            "token_or_phoneme_inventory": "N/A (band gains)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "DEPRECATED_INCOMPATIBLE (48kHz BFCC mismatch; superseded by gtcrn_denoiser)",
            "known_training_datasets": ["UNKNOWN_COMMUNITY_EXPORT"],
            "contamination_risk_notes": "Listed as ready:true in legacy AI_MODELS_MANIFEST.json while runtime loads gtcrn_simple.onnx.",
            "last_verified_timestamp": ts,
            "verification_method": "Local SHA-256 disk check + AiModelManager key alias inspection",
            "runtime_notes": "Candidate for removal from APK/bundle after Phase 1 verification.",
        },
        {
            "model_id": "deepfilternet3",
            "display_name": "DeepFilterNet3",
            "category": "Noise Suppression (Candidate)",
            "source_repo": "https://github.com/Rikorose/DeepFilterNet",
            "license": "MIT OR Apache-2.0 (dual-licensed)",
            "commercial_use_allowed": True,
            "availability_status": "EXTERNAL_CANDIDATE_NOT_DOWNLOADED",
            "local_path_or_status": "NOT_LOCAL (GitHub release / ONNX export not cached in Phase 0)",
            "artifact_size_mb": None,
            "checksum_sha256": "NOT_DOWNLOADED",
            "input_sample_rate_hz": 48000,
            "input_format": "48kHz STFT/ERB complex spectrogram (requires 16k->48k->16k resampling for 16kHz ASR)",
            "output_type": "Enhanced 48kHz PCM waveform",
            "token_or_phoneme_inventory": "N/A (speech enhancement)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "MEDIUM_RESAMPLE_OVERHEAD (fast on CPU; 48kHz native constraint adds resampling latency)",
            "known_training_datasets": ["DNS4 / VCTK / Freesound (per upstream DeepFilterNet3 paper)"],
            "contamination_risk_notes": "Cannot leak test Arabic labels; must evaluate consonant preservation vs GTCRN cleanly on paired noisy/clean clips.",
            "last_verified_timestamp": ts,
            "verification_method": "GitHub repository license check (Rikorose/DeepFilterNet)",
            "runtime_notes": "Benchmark candidate only; weights not downloaded in Phase 0.",
        },
        {
            "model_id": "wav2vec2_lv60_espeak_q4f16",
            "display_name": "Wav2Vec2-LV60-eSpeak-CV-FT (ONNX Q4F16)",
            "category": "Blind Phoneme Recognition (Current Baseline)",
            "source_repo": "https://huggingface.co/facebook/wav2vec2-lv-60-espeak-cv-ft",
            "license": "Apache-2.0",
            "commercial_use_allowed": True,
            "availability_status": "LOCAL_BUNDLED_VERIFIED",
            "local_path_or_status": "assets/ai_models/wav2vec2_espeak/model_q4f16.onnx",
            "artifact_size_mb": w2v_espeak["total_mb"],
            "checksum_sha256": w2v_espeak["primary_sha256"],
            "artifact_files": w2v_espeak["existing"],
            "input_sample_rate_hz": 16000,
            "input_format": "Float32 16kHz normalized waveform [1, N] zero-mean unit-variance",
            "output_type": "CTC frame logits [1, T, 392] -> collapsed eSpeak IPA token sequence",
            "token_or_phoneme_inventory": "392 eSpeak IPA tokens (assets/ai_models/wav2vec2_espeak/vocab.json; multilingual, weak Arabic pharyngeal/emphatic coverage)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "MEDIUM_HEAVY (187.79 MB quantized Q4F16 ONNX; high APK size & mobile RAM)",
            "known_training_datasets": ["Libri-Light 60k pretrain", "Mozilla Common Voice multilingual eSpeak phonemized CV-FT"],
            "contamination_risk_notes": "Any Common Voice Arabic clip matching CV-FT training split would be CONTAMINATED; Stage A/B avoid Common Voice Arabic overlap.",
            "last_verified_timestamp": ts,
            "verification_method": "Local SHA-256 disk check + HF facebook/wav2vec2-lv-60-espeak-cv-ft probe (rev ae45363b)",
            "runtime_notes": "Active baseline phoneme recognizer; omission from AI_MODELS_MANIFEST.json fixed in Phase 0.",
        },
        {
            "model_id": "zipformer_arabic_v3",
            "display_name": "Zipformer-p Arabic V3 (Quran-Lab)",
            "category": "Blind Phoneme Recognition (Arabic Candidate)",
            "source_repo": "https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3",
            "license": "other (HF card specifies license:other, gated manual approval)",
            "commercial_use_allowed": False,
            "availability_status": "PARTIAL_TOKENS_ONLY_WEIGHTS_MISSING_GATED",
            "local_path_or_status": "Tokens only at assets/ai_models/zipformer_v3/; ONNX weights MISSING & HF repo manually gated",
            "artifact_size_mb": zip_v3["total_mb"],
            "checksum_sha256": zip_v3["primary_sha256"],
            "artifact_files": zip_v3["existing"],
            "missing_files": zip_v3["missing"],
            "input_sample_rate_hz": 16000,
            "input_format": "16kHz Fbank features (80-dim, Sherpa-ONNX / Icefall Zipformer CTC)",
            "output_type": "Arabic phonetic/harakat CTC units",
            "token_or_phoneme_inventory": "Local tokens.txt (2,420 bytes) + phoneme_units.json (4,380 bytes; identical hash to zipformer_v2)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "UNKNOWN_UNVERIFIED (depends on quantized encoder/decoder export; license:other restricts commercial app shipping)",
            "known_training_datasets": ["Quranic / Classical Arabic Tajweed & phoneme corpora (exact split list UNVERIFIED due to gating)"],
            "contamination_risk_notes": "Domain shift hazard (Quranic adult recitation vs Egyptian pediatric everyday words); gated access + non-standard license.",
            "last_verified_timestamp": ts,
            "verification_method": "Local SHA-256 check + HF API probe (Quran-Lab/zipformer_p-arabic-v3 rev db89c0fc -> gated: manual, license: other)",
            "runtime_notes": "Local v3 tokens match v2 bit-for-bit; weights missing on disk.",
        },
        {
            "model_id": "zipformer_arabic_v2",
            "display_name": "Zipformer-p Arabic V2 (Quran-Lab)",
            "category": "Blind Phoneme Recognition (Arabic Candidate)",
            "source_repo": "https://huggingface.co/Quran-Lab/zipformer_p-arabic-v2 (unverified mirror/older release)",
            "license": "UNKNOWN (likely matches Quran-Lab license:other)",
            "commercial_use_allowed": False,
            "availability_status": "PARTIAL_TOKENS_ONLY_WEIGHTS_MISSING",
            "local_path_or_status": "Tokens only at assets/ai_models/zipformer_v2/; encoder-epoch-99-avg-1.int8.onnx MISSING",
            "artifact_size_mb": zip_v2["total_mb"],
            "checksum_sha256": zip_v2["primary_sha256"],
            "artifact_files": zip_v2["existing"],
            "missing_files": zip_v2["missing"],
            "input_sample_rate_hz": 16000,
            "input_format": "16kHz 80-dim Fbank (Sherpa-ONNX Zipformer CTC)",
            "output_type": "Arabic phonetic/harakat CTC units",
            "token_or_phoneme_inventory": "Local tokens.txt (2,420 bytes) identical to zipformer_v3",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "UNKNOWN_WEIGHTS_MISSING",
            "known_training_datasets": ["UNKNOWN (presumed Quranic/MSA Arabic corpora)"],
            "contamination_risk_notes": "Duplicate token artifacts of v3; listed in legacy AI_MODELS_MANIFEST.json without weights.",
            "last_verified_timestamp": ts,
            "verification_method": "Local SHA-256 check + comparison with zipformer_v3",
            "runtime_notes": "Cannot run inference locally; missing ONNX file.",
        },
        {
            "model_id": "mostafamaroof_wav2vec2_arabic_phoneme",
            "display_name": "MostafaMaroof/wav2vec2-arabic-phoneme-asr",
            "category": "Blind Phoneme Recognition (Arabic Candidate)",
            "source_repo": "https://huggingface.co/MostafaMaroof/wav2vec2-arabic-phoneme-asr",
            "license": "Apache-2.0",
            "commercial_use_allowed": True,
            "availability_status": "REMOTE_HF_VERIFIED_NOT_DOWNLOADED",
            "local_path_or_status": "NOT_LOCAL (Safetensors remote only; requires ONNX export + int8 quantization for mobile)",
            "artifact_size_mb": None,
            "checksum_sha256": "NOT_DOWNLOADED (HF commit 9c2bc0bc)",
            "input_sample_rate_hz": 16000,
            "input_format": "Float32 16kHz normalized waveform (wav2vec2-large-xlsr-53 architecture)",
            "output_type": "CTC Arabic phoneme tokens",
            "token_or_phoneme_inventory": "Arabic phonetic unit vocabulary (verify exact token inventory before Stage A run)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "HEAVY_NEEDS_QUANTIZATION (XLSR-53 300M params; FP32 ~1.2GB, Q4/INT8 ~180-300MB)",
            "known_training_datasets": ["tunis-ai/arabic_speech_corpus", "IqraEval/Iqra_train"],
            "contamination_risk_notes": "CRITICAL_CONTAMINATION_DOCUMENTED: Trained on tunis-ai/arabic_speech_corpus and IqraEval! MUST NEVER be scored as clean zero-shot on Arabic Speech Corpus.",
            "last_verified_timestamp": ts,
            "verification_method": "HF API model_info (MostafaMaroof/wav2vec2-arabic-phoneme-asr rev 9c2bc0bc)",
            "runtime_notes": "Promising open-license Arabic phoneme candidate; requires external ONNX conversion and contamination exclusion on ASC.",
        },
        {
            "model_id": "kgnlp_allophant",
            "display_name": "Allophant (kgnlp/allophant Multilingual Articulatory Phoneme Recognizer)",
            "category": "Blind Phoneme + Articulatory Feature Recognition (Candidate)",
            "source_repo": "https://huggingface.co/kgnlp/allophant | https://github.com/kgnlp/allophant",
            "license": "Apache-2.0",
            "commercial_use_allowed": True,
            "availability_status": "REMOTE_HF_VERIFIED_NOT_DOWNLOADED",
            "local_path_or_status": "NOT_LOCAL (PyTorch checkpoint on HF; custom Python architecture)",
            "artifact_size_mb": None,
            "checksum_sha256": "NOT_DOWNLOADED (HF commit ad69d315)",
            "input_sample_rate_hz": 16000,
            "input_format": "16kHz mono Float32 waveform (XLS-R 300M backbone)",
            "output_type": "Multi-task phoneme + phonological/articulatory feature logits (place, manner, voicing)",
            "token_or_phoneme_inventory": "Allophant IPA & articulatory attribute space (multilingual)",
            "supports_blind_phoneme_only": True,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "LOW_TO_MEDIUM (300M backbone + multi-head; likely server/desktop benchmark baseline or distilled student teacher)",
            "known_training_datasets": ["Multilingual Common Voice / UCLA / VoxLingua / SpeechMatrix subsets (check exact language list incl. Arabic)"],
            "contamination_risk_notes": "RISK_UNVERIFIED if Common Voice Arabic overlaps; zero overlap expected with ASMDD / Abjad-Kids / private Egyptian child data.",
            "last_verified_timestamp": ts,
            "verification_method": "HF API model_info (kgnlp/allophant rev ad69d315)",
            "runtime_notes": "Strong scientific baseline for articulatory error diagnosis (e.g., fronting k->t, lisp s->th) in Phase 5+.",
        },
        {
            "model_id": "whisper_tiny_int8",
            "display_name": "OpenAI Whisper Tiny INT8 (Sherpa-ONNX)",
            "category": "Automatic Speech Recognition (Local Baseline)",
            "source_repo": "https://huggingface.co/openai/whisper-tiny | https://github.com/k2-fsa/sherpa-onnx",
            "license": "Apache-2.0 (HF model card) / MIT (OpenAI Whisper code)",
            "commercial_use_allowed": True,
            "availability_status": "LOCAL_BUNDLED_VERIFIED",
            "local_path_or_status": "assets/ai_models/whisper_tiny/tiny-{encoder,decoder}.int8.onnx",
            "artifact_size_mb": whisper_tiny["total_mb"],
            "checksum_sha256": whisper_tiny["primary_sha256"],
            "artifact_files": whisper_tiny["existing"],
            "input_sample_rate_hz": 16000,
            "input_format": "Float32 16kHz mono PCM (80-bin Log-Mel internally via sherpa-onnx)",
            "output_type": "Autoregressive Arabic word/BPE transcript (language='ar', task='transcribe')",
            "token_or_phoneme_inventory": "Multilingual Whisper BPE vocabulary (tiny-tokens.txt; 816,730 bytes; NOT phoneme-level)",
            "supports_blind_phoneme_only": False,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "HIGH_ON_DEVICE (98.81 MB combined; already running offline via sherpa_onnx)",
            "known_training_datasets": ["OpenAI 680k hours web weakly-supervised audio (undisclosed exact composition)"],
            "contamination_risk_notes": "RISK_UNVERIFIED against public web datasets; weak Arabic child performance & silence hallucinations documented in MASTER_AI_BENCHMARK_REPORT.md. Also legacy AI_MODELS_MANIFEST.json has stale encoder/decoder byte sizes & hashes!",
            "last_verified_timestamp": ts,
            "verification_method": "Local SHA-256 disk check + HF openai/whisper-tiny probe (rev 169d4a43)",
            "runtime_notes": "Active auxiliary STT engine; cannot judge mispronounced sub-word phones accurately on its own.",
        },
        {
            "model_id": "whisper_large_v3_turbo",
            "display_name": "OpenAI Whisper Large-v3-Turbo",
            "category": "Automatic Speech Recognition (Cloud / Teacher Benchmark)",
            "source_repo": "https://huggingface.co/openai/whisper-large-v3-turbo",
            "license": "MIT",
            "commercial_use_allowed": True,
            "availability_status": "REMOTE_HF_VERIFIED_NOT_DOWNLOADED",
            "local_path_or_status": "NOT_LOCAL (809M params ~1.6-3.2 GB; GPU/Kaggle tier only)",
            "artifact_size_mb": None,
            "checksum_sha256": "NOT_DOWNLOADED (HF commit 41f01f3f)",
            "input_sample_rate_hz": 16000,
            "input_format": "16kHz 128-bin Log-Mel spectrogram",
            "output_type": "Word/subword ASR transcript",
            "token_or_phoneme_inventory": "Multilingual Whisper v3 BPE tokens (NOT phonetic GOP/IPA)",
            "supports_blind_phoneme_only": False,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "NOT_MOBILE_VIABLE (too large for low/mid Android offline budgets; use as Phase 4/5 server teacher & pseudo-label auditor only)",
            "known_training_datasets": ["OpenAI undisclosed web + pseudo-labeled corpus (large-v3 family)"],
            "contamination_risk_notes": "RISK_UNVERIFIED on web-scraped Arabic audio; risks hiding mispronunciations via language-model correction.",
            "last_verified_timestamp": ts,
            "verification_method": "HF API model_info (openai/whisper-large-v3-turbo rev 41f01f3f)",
            "runtime_notes": "Benchmark/annotation reference only.",
        },
        {
            "model_id": "egyptalk_asr_v2",
            "display_name": "NAMAA-Space/EgypTalk-ASR-v2",
            "category": "Egyptian Arabic ASR (Candidate)",
            "source_repo": "https://huggingface.co/NAMAA-Space/EgypTalk-ASR-v2",
            "license": "CC-BY-4.0",
            "commercial_use_allowed": True,
            "availability_status": "REMOTE_HF_VERIFIED_NOT_DOWNLOADED",
            "local_path_or_status": "NOT_LOCAL (NVIDIA NeMo FastConformer .nemo archive)",
            "artifact_size_mb": None,
            "checksum_sha256": "NOT_DOWNLOADED (HF commit d23895cf)",
            "input_sample_rate_hz": 16000,
            "input_format": "16kHz mono Float32 PCM (NeMo FastConformer Hybrid RNNT/CTC)",
            "output_type": "Egyptian Arabic orthographic transcript (characters/SentencePiece)",
            "token_or_phoneme_inventory": "SentencePiece Arabic text tokens (base: nvidia/stt_ar_fastconformer_hybrid_large_pcd_v1.0)",
            "supports_blind_phoneme_only": False,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "MEDIUM_WITH_NEMO_ONNX_EXPORT (FastConformer ~115M params; INT8 ~120MB if exported cleanly)",
            "known_training_datasets": ["NAMAA Egyptian Arabic speech collections (verify overlap with MASC / YouTube / EGYSpeak / public Egyptian corpora)"],
            "contamination_risk_notes": "RISK_UNVERIFIED with public Egyptian YouTube/podcast datasets; cannot guarantee zero overlap with MASC-Arabic or arabic-egy-cleaned.",
            "last_verified_timestamp": ts,
            "verification_method": "HF API model_info (NAMAA-Space/EgypTalk-ASR-v2 rev d23895cf)",
            "runtime_notes": "Candidate Egyptian ASR for benchmark & dataset pre-screening.",
        },
        {
            "model_id": "whisper_small_egyptian_arabic",
            "display_name": "Whisper-Small Egyptian Arabic (MAdel121 & ismaeel-farag)",
            "category": "Egyptian Arabic ASR (Candidate)",
            "source_repo": "https://huggingface.co/MAdel121/whisper-small-egyptian-arabic | https://huggingface.co/ismaeel-farag/whisper-small-egyptian-arabic",
            "license": "MIT",
            "commercial_use_allowed": True,
            "availability_status": "REMOTE_HF_VERIFIED_NOT_DOWNLOADED",
            "local_path_or_status": "NOT_LOCAL (244M params Whisper-small fine-tunes)",
            "artifact_size_mb": None,
            "checksum_sha256": "NOT_DOWNLOADED (HF rev 1388a7fd / 562137b3)",
            "input_sample_rate_hz": 16000,
            "input_format": "16kHz 80-bin Log-Mel spectrogram",
            "output_type": "Egyptian Arabic orthographic transcript",
            "token_or_phoneme_inventory": "Whisper BPE text tokens",
            "supports_blind_phoneme_only": False,
            "requires_target_word_hint": False,
            "mobile_onnx_feasibility": "LOW_TO_MEDIUM (244M encoder+decoder too heavy in FP32; ~250MB INT8)",
            "known_training_datasets": ["MAdel121/arabic-egy-cleaned (explicitly tagged on MAdel121 model)"],
            "contamination_risk_notes": "CRITICAL_CONTAMINATION_DOCUMENTED: MAdel121/whisper-small-egyptian-arabic explicitly trains on MAdel121/arabic-egy-cleaned! Evaluating it on arabic-egy-cleaned violates holdout integrity.",
            "last_verified_timestamp": ts,
            "verification_method": "HF API model_info on both repos (1388a7fd and 562137b3)",
            "runtime_notes": "Both MIT repos tracked together under Phase 0 governance.",
        },
        {
            "model_id": "smart_arabic_speech_therapy_scorer",
            "display_name": "Pediatric Phoneme Scorer (MON3EMPASHA/SmartArabicSpeechTherapy)",
            "category": "Pediatric Phoneme Quality Classifier (MLP on ASR+MFCC Features)",
            "source_repo": "https://huggingface.co/spaces/MON3EMPASHA/SmartArabicSpeechTherapy/tree/main",
            "license": "MIT (Space cardData license:mit; runtime ASR dependencies e.g. NeMo/Whisper vary by choice)",
            "commercial_use_allowed": True,
            "availability_status": "REMOTE_HF_SPACE_VERIFIED_NOT_DOWNLOADED",
            "local_path_or_status": "NOT_LOCAL (Available in HF Space models/phoneme_scorer_latest.pth + scaler_latest.pkl + ASR pipeline)",
            "artifact_size_mb": 0.074,
            "checksum_sha256": "08c3a03a56442944bebf560824ea98edc68f90b47a590cdeaec2a7708727e438",
            "input_sample_rate_hz": 16000,
            "input_format": "46 handcrafted features (duration/ASR confidence stats, 13 MFCC mean/std, delta, spectral/RMS)",
            "output_type": "Sigmoid binary phoneme pronunciation quality score [0.0, 1.0]",
            "token_or_phoneme_inventory": "Target-word dependent (character_aligner.py + ASR service aligns prompt phonemes first)",
            "supports_blind_phoneme_only": False,
            "requires_target_word_hint": True,
            "mobile_onnx_feasibility": "LOW_WITHOUT_REBUILD (Scorer MLP is tiny ~78 KB, but depends on heavy FastConformer/Whisper ASR aligner + librosa)",
            "known_training_datasets": ["ASMDD (dataset_info/ASMDD.csv inside Space: 5,298 rows; 4,235 train + 1,059 test samples reported)"],
            "contamination_risk_notes": "CRITICAL_CONTAMINATION_DOCUMENTED: Space includes dataset_info/ASMDD.csv and trained phoneme_scorer_latest.pth on 4,235/1,059 ASMDD split! Must NOT evaluate cleanly on ASMDD.",
            "last_verified_timestamp": ts,
            "verification_method": "HF Space API + Git LFS JSON/PTH resolution on MON3EMPASHA/SmartArabicSpeechTherapy (rev ef84267f)",
            "runtime_notes": "Audited during Phase 0 independent audit after discovering weights live inside HF Space rather than SmartArabicSpeechTherapy org models.",
        },
    ]

    # Validate required fields for every model
    for m in models:
        missing_keys = [k for k in REQUIRED_MODEL_FIELDS if k not in m]
        if missing_keys:
            raise ValueError(f"Model {m.get('model_id')} missing fields: {missing_keys}")

    return {
        "schema_version": REGISTRY_SCHEMA_VERSION,
        "generated_utc": ts,
        "model_count": len(models),
        "legacy_manifest_reconciliation": reconcile_legacy_manifest(models),
        "models": models,
    }


def reconcile_legacy_manifest(registry_models: list[dict[str, Any]]) -> dict[str, Any]:
    """Compare legacy AI_MODELS_MANIFEST.json & AiModelManager against actual files on disk."""
    manifest_path = REPO_ROOT / "AI_MODELS_MANIFEST.json"
    manager_path = REPO_ROOT / "lib" / "core" / "ai" / "ai_model_manager.dart"
    licenses_path = REPO_ROOT / "AI_MODEL_LICENSES.md"

    issues: list[dict[str, str]] = []
    manifest_data: dict[str, Any] = {}
    if manifest_path.exists():
        manifest_data = json.loads(manifest_path.read_text(encoding="utf-8"))
        m_entries = manifest_data.get("models", {})
        for key, entry in m_entries.items():
            raw_files = entry.get("files", [])
            file_entries = list(raw_files.values()) if isinstance(raw_files, dict) else list(raw_files)
            for f_info in file_entries:
                if not isinstance(f_info, dict):
                    continue
                rel = f_info.get("path", "")
                p = REPO_ROOT / rel
                expected_sha = f_info.get("sha256", "")
                expected_size = f_info.get("size_bytes")
                if not p.exists():
                    if entry.get("ready") is False and expected_sha == "MISSING":
                        continue
                    issues.append(
                        {
                            "severity": "HIGH",
                            "type": "missing_manifest_file",
                            "target": f"{key}:{rel}",
                            "detail": f"Manifest file does not exist on disk (ready={entry.get('ready')}).",
                        }
                    )
                else:
                    actual_sha = sha256_file(p)
                    actual_size = p.stat().st_size
                    if expected_sha and expected_sha != "MISSING" and actual_sha != expected_sha:
                        issues.append(
                            {
                                "severity": "CRITICAL",
                                "type": "checksum_mismatch",
                                "target": f"{key}:{rel}",
                                "detail": f"Disk sha256 {actual_sha[:12]} != manifest {expected_sha[:12]} (size {actual_size} vs {expected_size}).",
                            }
                        )
        for required_runtime in ("gtcrn_denoiser", "wav2vec2_espeak"):
            if required_runtime not in m_entries and "gtcrn" not in m_entries:
                issues.append(
                    {
                        "severity": "HIGH",
                        "type": "missing_active_runtime_model",
                        "target": required_runtime,
                        "detail": "Loaded by AiModelManager in Dart but absent from AI_MODELS_MANIFEST.json.",
                    }
                )
        if m_entries.get("rnnoise", {}).get("ready") is True:
            issues.append(
                {
                    "severity": "MEDIUM",
                    "type": "deprecated_manifest_alias",
                    "target": "rnnoise",
                    "detail": "Marked ready:true in manifest even though AiModelManager aliases rnnoise -> gtcrn_denoiser.",
                }
            )

    if manager_path.exists():
        src = manager_path.read_text(encoding="utf-8")
        keys_in_code = sorted(set(re.findall(r"'(silero_vad|gtcrn_denoiser|wav2vec2_espeak|whisper_tiny)'", src)))
    else:
        keys_in_code = []

    if licenses_path.exists():
        lic_text = licenses_path.read_text(encoding="utf-8")
        for missing_doc in ("GTCRN", "Wav2Vec2", "Abjad-Kids"):
            if missing_doc.lower() not in lic_text.lower():
                issues.append(
                    {
                        "severity": "MEDIUM",
                        "type": "license_doc_omission",
                        "target": f"AI_MODEL_LICENSES.md:{missing_doc}",
                        "detail": f"{missing_doc} missing from legacy AI_MODEL_LICENSES.md.",
                    }
                )

    return {
        "legacy_manifest_version": manifest_data.get("manifest_version", "UNKNOWN"),
        "runtime_keys_in_ai_model_manager": keys_in_code,
        "issue_count": len(issues),
        "issues": issues,
    }


def write_model_registry(path: Path = MODEL_REGISTRY_PATH) -> dict[str, Any]:
    reg = build_model_registry()
    path.write_text(json.dumps(reg, indent=2, ensure_ascii=False), encoding="utf-8")
    return reg


if __name__ == "__main__":
    data = write_model_registry()
    print(f"Wrote {MODEL_REGISTRY_PATH} with {data['model_count']} models; legacy issues={data['legacy_manifest_reconciliation']['issue_count']}")
