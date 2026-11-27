"""Independent adversarial audit tests verifying Phase 0 defenses against realistic attack vectors."""

from __future__ import annotations

import io
import json
import random
import shutil
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

from benchmarks.phase0.blind_protection import (
    BlindAuthorizationError,
    authorize_blind_execution,
    create_freeze_lock,
    strip_blind_labels,
    verify_blind_inference_signature,
)
from benchmarks.phase0.leakage_engine import acoustic_similarity, extract_audio_signature, run_leakage_audit
from benchmarks.phase0.metrics_engine import compute_assessment_metrics
from benchmarks.phase0.workspace_config import REPO_ROOT


def _save_wav(path: Path, samples: np.ndarray, sr: int = 16000, sampwidth: int = 2) -> None:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(sampwidth)
        wf.setframerate(sr)
        if sampwidth == 2:
            wf.writeframes(np.round(np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
        elif sampwidth == 1:
            wf.writeframes(np.round((np.clip(samples, -1.0, 1.0) + 1.0) * 127.5).astype(np.uint8).tobytes())
    path.write_bytes(buf.getvalue())


def _read_pcm16_samples(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as wf:
        frames = wf.readframes(wf.getnframes())
    return np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0


class IndependentAdversarialAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.base_clip = REPO_ROOT / "assets" / "audio_samples" / "human_arabic_adult.wav"
        self.other_clip = REPO_ROOT / "assets" / "audio_samples" / "word_madrasa.wav"

    def test_exact_renamed_resampled_trimmed_padded_and_noisy_duplicates(self) -> None:
        rng = np.random.default_rng(2026)
        base = _read_pcm16_samples(self.base_clip)

        with tempfile.TemporaryDirectory() as tmp:
            tp = Path(tmp)
            p_orig = tp / "stage_a_orig.wav"
            p_exact = tp / "stage_b_renamed_copy.wav"
            p_8k = tp / "stage_b_8k_pcm8.wav"
            p_trim = tp / "stage_b_trimmed_50pct.wav"
            p_pad = tp / "stage_b_silence_padded.wav"
            p_noisy = tp / "stage_b_snr10_noise.wav"
            p_distinct = tp / "stage_b_unrelated.wav"

            _save_wav(p_orig, base, sr=16000)
            p_exact.write_bytes(p_orig.read_bytes())

            idx8 = np.linspace(0, len(base) - 1, len(base) // 2)
            _save_wav(p_8k, np.interp(idx8, np.arange(len(base)), base), sr=8000, sampwidth=1)
            _save_wav(p_trim, base[: len(base) // 2], sr=16000)
            _save_wav(p_pad, np.concatenate([np.zeros(24000), base, np.zeros(32000)]), sr=16000)

            noise = rng.normal(0, 1, len(base)).astype(np.float32)
            noise *= np.sqrt(np.mean(base ** 2)) / (np.sqrt(np.mean(noise ** 2)) * (10.0 ** (10.0 / 20.0)))
            _save_wav(p_noisy, base + noise, sr=16000)
            shutil.copy2(self.other_clip, p_distinct)

            recs = [
                {"sample_id": "A_ORIG", "split": "stage_a", "dataset_id": "ds_a", "speaker_id": "SPK_A1", "file_path": str(p_orig)},
                {"sample_id": "B_EXACT", "split": "stage_b", "dataset_id": "ds_b", "speaker_id": "SPK_B1", "file_path": str(p_exact)},
                {"sample_id": "B_8K", "split": "stage_b", "dataset_id": "ds_b", "speaker_id": "SPK_B2", "file_path": str(p_8k)},
                {"sample_id": "B_TRIM", "split": "stage_b", "dataset_id": "ds_b", "speaker_id": "SPK_B3", "file_path": str(p_trim)},
                {"sample_id": "B_PAD", "split": "stage_b", "dataset_id": "ds_b", "speaker_id": "SPK_B4", "file_path": str(p_pad)},
                {"sample_id": "B_NOISY", "split": "stage_b", "dataset_id": "ds_b", "speaker_id": "SPK_B5", "file_path": str(p_noisy)},
                {"sample_id": "B_OTHER", "split": "stage_b", "dataset_id": "ds_b", "speaker_id": "SPK_B6", "file_path": str(p_distinct)},
            ]
            rep = run_leakage_audit(recs, tp)
            self.assertTrue(rep.has_critical_leakage)
            self.assertGreaterEqual(len(rep.exact_file_duplicates), 1)
            self.assertGreaterEqual(len(rep.cross_dataset_overlaps), 1)
            q = set(rep.quarantined_sample_ids)
            for attack_id in ("B_EXACT", "B_8K", "B_TRIM", "B_PAD", "B_NOISY"):
                self.assertIn(attack_id, q, f"Missed adversarial leakage copy: {attack_id}")
            self.assertNotIn("B_OTHER", q, "False positive quarantined unrelated speech!")

    def test_speaker_session_and_missing_speaker_audit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tp = Path(tmp)
            s1 = np.sin(2 * np.pi * 300 * np.arange(8000) / 16000.0).astype(np.float32) * 0.3
            s2 = np.sin(2 * np.pi * 900 * np.arange(8000) / 16000.0).astype(np.float32) * 0.3
            _save_wav(tp / "a.wav", s1)
            _save_wav(tp / "b.wav", s2)
            recs = [
                {"sample_id": "S1", "split": "stage_a", "speaker_id": "CHILD_1", "session_id": "SESS_9", "audio_type": "human_pediatric", "file_path": str(tp / "a.wav")},
                {"sample_id": "S2", "split": "stage_b", "speaker_id": "CHILD_1", "session_id": "SESS_9", "audio_type": "human_pediatric", "file_path": str(tp / "b.wav")},
                {"sample_id": "S3", "split": "stage_b", "speaker_id": "unknown", "audio_type": "human_pediatric", "file_path": str(tp / "b.wav")},
            ]
            rep = run_leakage_audit(recs, tp)
            self.assertEqual(len(rep.speaker_overlaps), 1)
            self.assertEqual(len(rep.session_overlaps), 1)
            self.assertEqual(len(rep.missing_speaker_records), 1)
            self.assertIn("S3", rep.missing_speaker_records[0].sample_ids)

    def test_blind_freeze_rejects_empty_and_unknown_speakers_and_tampered_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # Create minimal isolated disk artifact & code layout inside tmp
            model_file = root / "assets" / "ai_models" / "silero" / "silero_vad.onnx"
            code_file = root / "lib" / "core" / "ai" / "audio_preprocessor.dart"
            manifest_file = root / "AI_MODELS_MANIFEST.json"
            wav_file = root / "audio" / "b1.wav"
            for f in (model_file, code_file, manifest_file, wav_file):
                f.parent.mkdir(parents=True, exist_ok=True)
            model_file.write_bytes(b"ORIGINAL_MODEL_WEIGHTS")
            code_file.write_text("double preprocess() => 16000;", encoding="utf-8")
            manifest_file.write_text('{"manifest_version": "2.0.0"}', encoding="utf-8")
            _save_wav(wav_file, np.sin(2 * np.pi * 400 * np.arange(8000) / 16000.0).astype(np.float32) * 0.2)

            stage_a = [{"sample_id": "A1", "speaker_id": "SPK_A1", "audio_type": "human_pediatric"}]

            # 1. Empty Stage B rejected
            with self.assertRaises(BlindAuthorizationError):
                create_freeze_lock(stage_a, [], {}, verify_disk_system=False)

            # 2. Unknown speaker ID rejected (never assumed disjoint!)
            bad_b = [{"sample_id": "B_UNK", "speaker_id": "", "audio_type": "human_pediatric"}]
            with self.assertRaises(BlindAuthorizationError):
                create_freeze_lock(stage_a, bad_b, {}, verify_disk_system=False)

            # 3. Full lock against actual files on disk
            from benchmarks.phase0 import blind_protection as bp

            orig_models = bp.DEFAULT_MODEL_ARTIFACTS
            orig_code = bp.DEFAULT_PREPROCESSING_CODE
            try:
                bp.DEFAULT_MODEL_ARTIFACTS = ["AI_MODELS_MANIFEST.json", "assets/ai_models/silero/silero_vad.onnx"]
                bp.DEFAULT_PREPROCESSING_CODE = ["lib/core/ai/audio_preprocessor.dart"]

                stage_b_raw = [{"sample_id": "B1", "speaker_id": "SPK_B1", "file_path": "audio/b1.wav", "target_word": "كورة", "expected_outcome": "pass", "audio_type": "human_pediatric"}]
                inputs, labels = strip_blind_labels(stage_b_raw)
                lock = create_freeze_lock(
                    stage_a,
                    inputs,
                    labels,
                    thresholds_config={"pass": 75},
                    preprocessing_config={"sr": 16000},
                    repo_root=root,
                    audio_root=root,
                    verify_disk_system=True,
                )
                self.assertTrue(
                    authorize_blind_execution(
                        lock,
                        inputs,
                        thresholds_config={"pass": 75},
                        preprocessing_config={"sr": 16000},
                        repo_root=root,
                        audio_root=root,
                        verify_disk_system=True,
                    )["authorized"]
                )

                # Tamper WAV audio on disk -> must fail
                _save_wav(wav_file, np.zeros(8000, dtype=np.float32))
                with self.assertRaises(BlindAuthorizationError):
                    authorize_blind_execution(lock, inputs, thresholds_config={"pass": 75}, preprocessing_config={"sr": 16000}, repo_root=root, audio_root=root)
                _save_wav(wav_file, np.sin(2 * np.pi * 400 * np.arange(8000) / 16000.0).astype(np.float32) * 0.2)

                # Modify model weight bytes on disk -> must fail
                model_file.write_bytes(b"TAMPERED_WEIGHTS")
                with self.assertRaises(BlindAuthorizationError):
                    authorize_blind_execution(lock, inputs, thresholds_config={"pass": 75}, preprocessing_config={"sr": 16000}, repo_root=root, audio_root=root)
                model_file.write_bytes(b"ORIGINAL_MODEL_WEIGHTS")

                # Modify manifest on disk -> must fail
                manifest_file.write_text('{"manifest_version": "tampered"}', encoding="utf-8")
                with self.assertRaises(BlindAuthorizationError):
                    authorize_blind_execution(lock, inputs, thresholds_config={"pass": 75}, preprocessing_config={"sr": 16000}, repo_root=root, audio_root=root)
                manifest_file.write_text('{"manifest_version": "2.0.0"}', encoding="utf-8")

                # Modify preprocessing code on disk -> must fail
                code_file.write_text("double preprocess() => 8000;", encoding="utf-8")
                with self.assertRaises(BlindAuthorizationError):
                    authorize_blind_execution(lock, inputs, thresholds_config={"pass": 75}, preprocessing_config={"sr": 16000}, repo_root=root, audio_root=root)
                code_file.write_text("double preprocess() => 16000;", encoding="utf-8")

                # Change threshold after freeze -> must fail
                with self.assertRaises(BlindAuthorizationError):
                    authorize_blind_execution(lock, inputs, thresholds_config={"pass": 50}, preprocessing_config={"sr": 16000}, repo_root=root, audio_root=root)
            finally:
                bp.DEFAULT_MODEL_ARTIFACTS = orig_models
                bp.DEFAULT_PREPROCESSING_CODE = orig_code

    def test_random_label_permutation_and_target_hint_block(self) -> None:
        def bad_adapter(pcm: np.ndarray, expected_word: str) -> str:
            return expected_word

        with self.assertRaises(BlindAuthorizationError):
            verify_blind_inference_signature(bad_adapter)

        preds = [i < 100 for i in range(200)]
        rng = random.Random(1337)
        perm = list(preds)
        rng.shuffle(perm)
        items = [{"expected_pass": y, "predicted_pass": p, "speaker_id": f"S{i}"} for i, (y, p) in enumerate(zip(perm, preds))]
        res = compute_assessment_metrics(items)
        self.assertLess(res["balanced_accuracy"], 0.65)
        self.assertGreater(res["balanced_accuracy"], 0.35)


if __name__ == "__main__":
    unittest.main()
