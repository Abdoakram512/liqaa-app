"""Automated unit tests for Yasser Phase 0 AI Governance, Leakage, Blindness & Metrics."""

from __future__ import annotations

import io
import math
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

from benchmarks.phase0.anti_cheating_suite import run_all_15_anti_cheating_tests
from benchmarks.phase0.blind_protection import (
    BlindAuthorizationError,
    authorize_blind_execution,
    create_freeze_lock,
    strip_blind_labels,
    verify_blind_inference_signature,
)
from benchmarks.phase0.contamination_matrix import build_contamination_matrix
from benchmarks.phase0.dataset_registry import MUTUAL_EXCLUSION_RULES, build_dataset_registry
from benchmarks.phase0.leakage_engine import run_leakage_audit
from benchmarks.phase0.metrics_engine import (
    compute_assessment_metrics,
    compute_noise_suppression_metrics,
    compute_phoneme_metrics,
    compute_runtime_metrics,
    compute_stt_metrics,
    compute_vad_metrics,
    wilson_ci,
)
from benchmarks.phase0.model_registry import build_model_registry


def _write_wav(path: Path, samples: np.ndarray, sr: int = 16000, channels: int = 1) -> None:
    buf = io.BytesIO()
    clipped = np.clip(samples, -1.0, 1.0)
    if channels > 1:
        clipped = np.repeat(clipped[:, None], channels, axis=1).reshape(-1)
    pcm = np.round(clipped * 32767.0).astype("<i2")
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(pcm.tobytes())
    path.write_bytes(buf.getvalue())


class Phase0GovernanceTests(unittest.TestCase):
    def test_model_registry_covers_all_13_candidates(self) -> None:
        reg = build_model_registry(verified_ts="2026-11-27T00:00:00Z")
        ids = {m["model_id"] for m in reg["models"]}
        expected = {
            "silero_vad_v4",
            "gtcrn_denoiser",
            "deepfilternet3",
            "wav2vec2_lv60_espeak_q4f16",
            "zipformer_arabic_v3",
            "zipformer_arabic_v2",
            "mostafamaroof_wav2vec2_arabic_phoneme",
            "kgnlp_allophant",
            "whisper_tiny_int8",
            "whisper_large_v3_turbo",
            "egyptalk_asr_v2",
            "whisper_small_egyptian_arabic",
            "smart_arabic_speech_therapy_scorer",
        }
        self.assertTrue(expected.issubset(ids))
        smart = next(m for m in reg["models"] if m["model_id"] == "smart_arabic_speech_therapy_scorer")
        self.assertEqual(smart["availability_status"], "REMOTE_HF_SPACE_VERIFIED_NOT_DOWNLOADED")
        self.assertIn("MIT", smart["license"])
        self.assertEqual(
            smart["checksum_sha256"],
            "08c3a03a56442944bebf560824ea98edc68f90b47a590cdeaec2a7708727e438",
        )

    def test_dataset_registry_stage_quotas_and_zero_blind_synthetic(self) -> None:
        reg = build_dataset_registry(verified_ts="2026-11-27T00:00:00Z")
        self.assertEqual(reg["split_quotas"]["stage_a"]["total_target_samples"], 2000)
        self.assertEqual(reg["split_quotas"]["stage_b_blind"]["total_target_samples"], 1500)
        self.assertFalse(reg["split_quotas"]["stage_b_blind"]["allow_synthetic"])
        self.assertEqual(reg["split_quotas"]["stage_b_blind"]["category_quotas"]["controlled_synthetic"], 0)
        self.assertEqual(len(MUTUAL_EXCLUSION_RULES), 4)

    def test_contamination_matrix_flags_known_overlaps(self) -> None:
        rows = build_contamination_matrix()
        lookup = {(r["model_id"], r["dataset_id"]): r for r in rows}
        self.assertEqual(
            lookup[("mostafamaroof_wav2vec2_arabic_phoneme", "arabic_speech_corpus")]["contamination_status"],
            "DIRECT_OVERLAP",
        )
        self.assertEqual(
            lookup[("whisper_small_egyptian_arabic", "arabic_egy_cleaned")]["contamination_status"],
            "DIRECT_OVERLAP",
        )
        self.assertEqual(
            lookup[("smart_arabic_speech_therapy_scorer", "asmdd")]["contamination_status"],
            "DIRECT_OVERLAP",
        )

    def test_leakage_catches_trimmed_resampled_and_noise_variants(self) -> None:
        rng = np.random.default_rng(123)
        t = np.linspace(0, 1.0, 16000, dtype=np.float32)
        speech_like = (0.35 * np.sin(2 * np.pi * (240 + 180 * t) * t) + 0.12 * np.sin(2 * np.pi * 1400 * t)).astype(np.float32)

        with tempfile.TemporaryDirectory() as tmp:
            tp = Path(tmp)
            p_orig = tp / "a.wav"
            p_resamp = tp / "b_22k_gain.wav"
            p_trimmed = tp / "c_trimmed.wav"
            p_diff = tp / "d_other.wav"

            _write_wav(p_orig, speech_like, sr=16000)
            # Resampled & gain scaled copy
            idx22 = np.linspace(0, len(speech_like) - 1, 22050)
            resamp = np.interp(idx22, np.arange(len(speech_like)), speech_like * 0.65).astype(np.float32)
            _write_wav(p_resamp, resamp, sr=22050)
            # Trimmed middle 70% + subtle noise
            trimmed = speech_like[1500:14500] + rng.normal(0, 0.01, 13000).astype(np.float32)
            _write_wav(p_trimmed, trimmed, sr=16000)
            # Distinct signal (high harmonic sweep descending)
            distinct = (0.35 * np.sin(2 * np.pi * (2600 - 1500 * t) * t)).astype(np.float32)
            _write_wav(p_diff, distinct, sr=16000)

            recs = [
                {"sample_id": "S1", "split": "stage_a", "speaker_id": "SPK1", "file_path": str(p_orig)},
                {"sample_id": "S2", "split": "stage_b", "speaker_id": "SPK2", "file_path": str(p_resamp)},
                {"sample_id": "S3", "split": "stage_b", "speaker_id": "SPK3", "file_path": str(p_trimmed)},
                {"sample_id": "S4", "split": "stage_b", "speaker_id": "SPK4", "file_path": str(p_diff)},
            ]
            rep = run_leakage_audit(recs, tp)
            self.assertTrue(rep.has_critical_leakage)
            flagged_ids = {sid for f in rep.acoustic_near_duplicates for sid in f.sample_ids}
            self.assertIn("S1", flagged_ids)
            self.assertIn("S2", flagged_ids)
            self.assertNotIn("S4", flagged_ids)

    def test_blind_protection_strips_labels_and_blocks_drift(self) -> None:
        stage_a = [{"sample_id": "A1", "speaker_id": "SA1"}]
        stage_b_raw = [
            {
                "sample_id": "B1",
                "speaker_id": "SB1",
                "file_path": "x.wav",
                "target_word": "كورة",
                "expected_outcome": "pass",
                "audio_type": "human_pediatric",
            }
        ]
        inputs, labels = strip_blind_labels(stage_b_raw)
        self.assertNotIn("target_word", inputs[0])
        self.assertEqual(labels["B1"]["target_word"], "كورة")

        lock = create_freeze_lock(stage_a, inputs, labels, {"rev": "r1"}, {"thr": 0.5}, {"sr": 16000})
        auth = authorize_blind_execution(lock, inputs, {"rev": "r1"}, {"thr": 0.5}, {"sr": 16000})
        self.assertTrue(auth["authorized"])

        with self.assertRaises(BlindAuthorizationError):
            authorize_blind_execution(lock, inputs, {"rev": "r2"}, {"thr": 0.5}, {"sr": 16000})

        def sneaky(audio: np.ndarray, expected_phonemes: list[str]) -> None:
            _ = (audio, expected_phonemes)

        with self.assertRaises(BlindAuthorizationError):
            verify_blind_inference_signature(sneaky)

    def test_metrics_engine_exactness_and_wilson_ci(self) -> None:
        ci = wilson_ci(0, 0)
        self.assertIsNone(ci["rate"])
        ci_valid = wilson_ci(18, 20)
        self.assertAlmostEqual(ci_valid["rate"], 0.9)
        self.assertLess(ci_valid["ci_low"], 0.9)
        self.assertGreater(ci_valid["ci_high"], 0.9)

        vad = compute_vad_metrics([True, True, False, False], [True, False, True, False])
        self.assertAlmostEqual(vad["balanced_accuracy"], 0.5)

        t = np.linspace(0, 1, 16000)
        clean = np.sin(2 * np.pi * 440 * t)
        noisy = clean + 0.3 * np.sin(2 * np.pi * 1500 * t)
        ns = compute_noise_suppression_metrics([clean], [noisy], [clean])
        self.assertGreater(ns["mean_sisdr_gain_db"], 10.0)

        stt = compute_stt_metrics(["أحمد مدرسة", ""], ["احمد مدرسه", "هلوسة"], is_non_speech=[False, True])
        self.assertAlmostEqual(stt["wer"], 0.0)
        self.assertAlmostEqual(stt["silence_noise_hallucination"]["rate"], 1.0)

        ph = compute_phoneme_metrics([["k", "u", "r", "a"]], [["t", "u", "r", "a"]])
        self.assertAlmostEqual(ph["per"], 0.25)
        self.assertEqual(ph["top_confusions"][0]["ref"], "k")
        self.assertEqual(ph["top_confusions"][0]["hyp"], "t")

        assess = compute_assessment_metrics(
            [
                {"expected_pass": True, "predicted_pass": True, "speaker_id": "S1"},
                {"expected_pass": False, "predicted_pass": False, "speaker_id": "S2"},
                {"expected_pass": False, "predicted_pass": True, "speaker_id": "S2"},
            ]
        )
        self.assertEqual(assess["speaker_count"], 2)
        self.assertAlmostEqual(assess["speaker_level_macro_accuracy"], 0.75)

        rt = compute_runtime_metrics([100, 120, 140, 200], [1000, 1000, 1000, 1000], [110.0, 125.0])
        self.assertEqual(rt["cold_first_latency_ms"], 100.0)
        self.assertEqual(rt["peak_ram_mb"], 125.0)

    def test_all_15_anti_cheating_checks_pass(self) -> None:
        suite = run_all_15_anti_cheating_tests()
        self.assertEqual(suite["passed_count"], 15, f"Anti-cheating failures: {suite}")


if __name__ == "__main__":
    unittest.main()
