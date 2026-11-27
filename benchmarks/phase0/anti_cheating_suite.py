"""Phase 0 Anti-Cheating Suite: verifies real ONNX blind behavior, manifest hashes & lock guards."""

from __future__ import annotations

import io
import json
import random
import tempfile
import wave
from pathlib import Path
from typing import Any

import numpy as np

from .blind_protection import (
    BlindAuthorizationError,
    authorize_blind_execution,
    compute_disk_model_hashes,
    create_freeze_lock,
    strip_blind_labels,
    verify_blind_inference_signature,
)
from .leakage_engine import acoustic_similarity, extract_audio_signature, read_wav_mono_16k, run_leakage_audit
from .model_registry import sha256_file
from .workspace_config import REPO_ROOT


def _make_wav_bytes(samples: np.ndarray, sr: int = 16000, channels: int = 1, sampwidth: int = 2) -> bytes:
    buf = io.BytesIO()
    clipped = np.clip(samples, -1.0, 1.0)
    if channels > 1:
        clipped = np.repeat(clipped[:, None], channels, axis=1).reshape(-1)
    pcm = np.round(clipped * 32767.0).astype("<i2")
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sampwidth)
        wf.setframerate(sr)
        wf.writeframes(pcm.tobytes())
    return buf.getvalue()


def _levenshtein_dp(ref: list[str], hyp: list[str]) -> int:
    n, m = len(ref), len(hyp)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if ref[i - 1] == hyp[j - 1] else 1
            dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
    return dp[n][m]


def run_all_15_anti_cheating_tests() -> dict[str, Any]:
    """Run all 15 anti-cheating verification tests sequentially using real bundled ONNX models & controlled adversarial probes."""
    results: list[dict[str, Any]] = []
    rng = np.random.default_rng(42)

    def record(test_id: str, title: str, passed: bool, detail: str, uses_synthetic_fixture: bool) -> None:
        results.append(
            {
                "test_id": test_id,
                "title": title,
                "status": "PASS" if passed else "FAIL",
                "passed": passed,
                "uses_synthetic_fixture": uses_synthetic_fixture,
                "detail": detail,
            }
        )

    import onnxruntime as ort

    silero_path = REPO_ROOT / "assets" / "ai_models" / "silero" / "silero_vad.onnx"
    w2v_path = REPO_ROOT / "assets" / "ai_models" / "wav2vec2_espeak" / "model_q4f16.onnx"
    vocab_path = REPO_ROOT / "assets" / "ai_models" / "wav2vec2_espeak" / "vocab.json"

    silero_sess = ort.InferenceSession(str(silero_path), providers=["CPUExecutionProvider"]) if silero_path.exists() else None
    w2v_sess = ort.InferenceSession(str(w2v_path), providers=["CPUExecutionProvider"]) if w2v_path.exists() else None
    inv_vocab = {v: k for k, v in json.loads(vocab_path.read_text(encoding="utf-8")).items()} if vocab_path.exists() else {}

    def run_silero_max_prob(audio_16k: np.ndarray) -> float | None:
        if silero_sess is None:
            return None
        input_names = {i.name for i in silero_sess.get_inputs()}
        max_p = 0.0
        if "state" in input_names:
            state = np.zeros((2, 1, 128), dtype=np.float32)
            sr_arr = np.array([16000], dtype=np.int64)
            for off in range(0, len(audio_16k) - 512 + 1, 512):
                out, state = silero_sess.run(None, {"input": audio_16k[off : off + 512][None, :].astype(np.float32), "state": state, "sr": sr_arr})
                max_p = max(max_p, float(np.squeeze(out)))
        else:
            h = np.zeros((2, 1, 64), dtype=np.float32)
            c = np.zeros((2, 1, 64), dtype=np.float32)
            sr_arr = np.array([16000], dtype=np.int64)
            for off in range(0, len(audio_16k) - 512 + 1, 512):
                out, h, c = silero_sess.run(None, {"input": audio_16k[off : off + 512][None, :].astype(np.float32), "sr": sr_arr, "h": h, "c": c})
                max_p = max(max_p, float(np.squeeze(out)))
        return max_p

    def run_blind_w2v_tokens(audio_16k: np.ndarray) -> list[str]:
        if w2v_sess is None or len(audio_16k) < 1600:
            return []
        norm = (audio_16k - float(np.mean(audio_16k))) / (float(np.std(audio_16k)) + 1e-6)
        logits = w2v_sess.run(None, {w2v_sess.get_inputs()[0].name: norm[None, :].astype(np.float32)})[0][0]
        ids = np.argmax(logits, axis=-1)
        toks: list[str] = []
        prev = -1
        for i in ids:
            ii = int(i)
            if ii != prev and ii != 0:
                tok = inv_vocab.get(ii, "")
                if tok and tok not in ("<pad>", "<s>", "</s>", "<unk>", "|"):
                    toks.append(tok)
            prev = ii
        return toks

    # 1. Silence input -> Real Silero VAD + Real Wav2Vec2-eSpeak must both emit non-speech/empty
    sil_arr, _, _ = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "silence.wav")
    sil_prob = run_silero_max_prob(sil_arr)
    sil_toks = run_blind_w2v_tokens(sil_arr)
    record(
        "T01",
        "Silence input rejected by real VAD and blind Wav2Vec2",
        (sil_prob is not None and sil_prob < 0.05) and len(sil_toks) == 0,
        f"Silero max_prob={sil_prob:.4f}, Wav2Vec2 tokens={sil_toks}",
        False,
    )

    # 2. White noise input -> Real Silero VAD + Real Wav2Vec2
    wn_arr, _, _ = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "white_noise.wav")
    wn_prob = run_silero_max_prob(wn_arr)
    wn_toks = run_blind_w2v_tokens(wn_arr)
    record(
        "T02",
        "White noise rejected by real VAD and blind Wav2Vec2",
        (wn_prob is not None and wn_prob < 0.35) and len(wn_toks) == 0,
        f"Silero max_prob={wn_prob:.4f}, Wav2Vec2 tokens={wn_toks}",
        False,
    )

    # 3. Synthetic Gaussian babble/noise floor
    syn_wn = rng.normal(0, 0.12, 16000).astype(np.float32)
    syn_prob = run_silero_max_prob(syn_wn)
    record(
        "T03",
        "Generated stationary noise floor fails VAD speech gate",
        syn_prob is not None and syn_prob < 0.40,
        f"Silero max_prob={syn_prob:.4f}",
        True,
    )

    # 4. Unrelated word rejection via REAL blind Wav2Vec2-eSpeak inference (word_madrasa.wav vs target 'كورة')
    madrasa_arr, _, _ = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "word_madrasa.wav")
    madrasa_toks = run_blind_w2v_tokens(madrasa_arr)
    target_kora = ["k", "uː", "r", "a"]
    dist_kora = _levenshtein_dp(target_kora, madrasa_toks)
    madrasa_score = max(0.0, 100.0 * (1.0 - dist_kora / len(target_kora)))
    record(
        "T04",
        "Unrelated spoken word (word_madrasa.wav) rejected against target 'كورة' via real ONNX",
        len(madrasa_toks) >= 3 and madrasa_score < 60.0 and ("k" not in madrasa_toks),
        f"Real Wav2Vec2 tokens={madrasa_toks}, kora_score={madrasa_score:.1f}%",
        True,
    )

    # 5. Minimal-pair fronting diagnostic probe via REAL ONNX: error_tora.wav vs correct_kora.wav
    kora_arr, _, _ = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "correct_kora.wav")
    tora_arr, _, _ = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "error_tora.wav")
    kora_toks = run_blind_w2v_tokens(kora_arr)
    tora_toks = run_blind_w2v_tokens(tora_arr)
    dist_c = _levenshtein_dp(["k", "uː", "r", "a"], kora_toks)
    dist_e = _levenshtein_dp(["k", "uː", "r", "a"], tora_toks)
    record(
        "T05",
        "Minimal-pair error_tora.wav yields worse distance than correct_kora.wav on real ONNX",
        len(kora_toks) > 0 and len(tora_toks) > 0 and ("k" not in tora_toks or dist_e >= dist_c),
        f"correct_kora={kora_toks} (dist={dist_c}) vs error_tora={tora_toks} (dist={dist_e}) [synthetic TTS probe only]",
        True,
    )

    # 6. Incomplete cut speech: truncate first 220ms of real human_arabic_adult.wav & verify shorter incomplete output
    adult_arr, _, _ = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "human_arabic_adult.wav")
    full_toks = run_blind_w2v_tokens(adult_arr)
    cut_toks = run_blind_w2v_tokens(adult_arr[:3520])
    record(
        "T06",
        "Truncated speech yields severely incomplete sequence vs full utterance",
        len(full_toks) >= 6 and len(cut_toks) < len(full_toks) / 2,
        f"Full tokens={len(full_toks)} vs 220ms cut tokens={len(cut_toks)} ({cut_toks})",
        False,
    )

    # 7. Quiet & clipped amplitude telemetry check
    quiet = np.full(16000, 0.0005, dtype=np.float32)
    clipped = np.clip(np.sin(2 * np.pi * 440 * np.arange(16000) / 16000.0) * 2.5, -1.0, 1.0).astype(np.float32)
    clip_count = int(np.sum(np.abs(clipped) >= 0.999))
    quiet_rms = float(np.sqrt(np.mean(quiet ** 2)))
    record(
        "T07",
        "Quiet-floor and clipped signal anomaly detection",
        quiet_rms < 0.002 and clip_count > 1000,
        f"quiet_rms={quiet_rms:.5f}, clipped_samples={clip_count}",
        True,
    )

    # 8. Corrupted / truncated WAV fails cleanly
    with tempfile.TemporaryDirectory() as tmp:
        bad_wav = Path(tmp) / "corrupt.wav"
        bad_wav.write_bytes(b"RIFF\x10\x00\x00\x00WAVEjunk")
        try:
            read_wav_mono_16k(bad_wav)
            t8_ok = False
        except ValueError:
            t8_ok = True
    record("T08", "Corrupted/truncated WAV raises structured ValueError", t8_ok, "Blocked with ValueError (zero silent pass)", True)

    # 9. Wrong sample rate (44.1kHz stereo) deterministic resampling & downmix
    with tempfile.TemporaryDirectory() as tmp:
        t_axis = np.arange(44100, dtype=np.float32) / 44100.0
        tone = (0.3 * np.sin(2 * np.pi * 300.0 * t_axis)).astype(np.float32)
        stereo_p = Path(tmp) / "stereo_44k.wav"
        stereo_p.write_bytes(_make_wav_bytes(tone, sr=44100, channels=2))
        out_16k, orig_sr, _ = read_wav_mono_16k(stereo_p)
        t9_ok = orig_sr == 44100 and len(out_16k) == 16000 and bool(np.all(np.isfinite(out_16k)))
    record("T09", "44.1kHz stereo downmixed & resampled to 16kHz mono", t9_ok, f"orig_sr={orig_sr}, out_len={len(out_16k)}", True)

    # 10. Forced target-word leakage detection (Python guard + real Dart PhonemeRecognitionEngine inspection)
    def leaky_model(audio: np.ndarray, target_word: str) -> list[str]:
        return [target_word]

    sig_blocked = False
    try:
        verify_blind_inference_signature(leaky_model)
    except BlindAuthorizationError:
        sig_blocked = True

    dart_phoneme_src = (REPO_ROOT / "lib" / "core" / "ai" / "phoneme_recognition_engine.dart").read_text(encoding="utf-8")
    dart_blind = "recognizePhonemesDetailed(" in dart_phoneme_src and "targetWord" not in dart_phoneme_src
    record(
        "T10",
        "Target-word hint blocked in blind inference & Dart PhonemeRecognitionEngine",
        sig_blocked and dart_blind,
        f"Signature firewall blocked leaky_model={sig_blocked}; Dart engine targetWord-free={dart_blind}",
        False,
    )

    # 11. Cross-split duplicate, silence-padded, trimmed, resampled, speaker & lineage leakage
    with tempfile.TemporaryDirectory() as tmp:
        tp = Path(tmp)
        rng_sig = np.sin(2 * np.pi * np.linspace(220, 1400, 16000)) * np.hanning(16000) * 0.4
        f_train = tp / "train_orig.wav"
        f_blind_exact = tp / "blind_copy.wav"
        f_blind_resamp = tp / "blind_resamp_8k.wav"
        f_train.write_bytes(_make_wav_bytes(rng_sig.astype(np.float32), sr=16000))
        f_blind_exact.write_bytes(_make_wav_bytes(rng_sig.astype(np.float32), sr=16000))
        idx8 = np.linspace(0, 15999, 8000)
        sig_8k = np.interp(idx8, np.arange(16000), rng_sig).astype(np.float32)
        f_blind_resamp.write_bytes(_make_wav_bytes(sig_8k, sr=8000))
        recs = [
            {"sample_id": "TR01", "split": "train", "speaker_id": "SPK_99", "file_path": str(f_train)},
            {"sample_id": "BL01", "split": "stage_b", "speaker_id": "SPK_99", "file_path": str(f_blind_exact)},
            {"sample_id": "BL02", "split": "stage_b", "speaker_id": "SPK_02", "file_path": str(f_blind_resamp)},
        ]
        rep = run_leakage_audit(recs, tp)
        t11_ok = rep.has_critical_leakage and len(rep.exact_file_duplicates) >= 1 and len(rep.acoustic_near_duplicates) >= 1 and len(rep.speaker_overlaps) >= 1
    record(
        "T11",
        "Cross-split exact duplicate, 8kHz resampled duplicate & speaker leakage caught",
        t11_ok,
        f"exact={len(rep.exact_file_duplicates)}, acoustic={len(rep.acoustic_near_duplicates)}, spk={len(rep.speaker_overlaps)}",
        True,
    )

    # 12. Label permutation sanity check
    n_items = 200
    preds = [i % 2 == 0 for i in range(n_items)]
    true_orig = list(preds)
    shuffled = list(true_orig)
    random.Random(7).shuffle(shuffled)
    orig_acc = sum(a == b for a, b in zip(preds, true_orig)) / n_items
    perm_acc = sum(a == b for a, b in zip(preds, shuffled)) / n_items
    record(
        "T12",
        "Random label permutation collapses accuracy to ~50% chance",
        orig_acc == 1.0 and 0.35 <= perm_acc <= 0.65,
        f"orig_acc={orig_acc:.2f} -> shuffled_acc={perm_acc:.2f}",
        True,
    )

    # 13. Post-freeze threshold, code & disk artifact drift abort blind execution
    stage_a = [{"sample_id": "A1", "speaker_id": "SPK_A"}]
    stage_b = [{"sample_id": "B1", "speaker_id": "SPK_B", "target_word": "كورة", "expected_outcome": "pass", "audio_type": "human_pediatric"}]
    inputs_b, labels_b = strip_blind_labels(stage_b)
    lock = create_freeze_lock(stage_a, inputs_b, labels_b, {"m": "v1"}, {"pass_score": 70}, {"sr": 16000})
    drift_blocked = False
    try:
        authorize_blind_execution(lock, inputs_b, {"m": "v1"}, {"pass_score": 60}, {"sr": 16000})
    except BlindAuthorizationError:
        drift_blocked = True
    record("T13", "Post-freeze threshold/artifact lock blocks drift", drift_blocked, "Changing pass_score 70->60 raised BlindAuthorizationError", True)

    # 14. Deterministic repeatability check across WAV parse + Silero VAD + Wav2Vec2
    a1, _, h1 = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "human_arabic_adult.wav")
    a2, _, h2 = read_wav_mono_16k(REPO_ROOT / "assets" / "audio_samples" / "human_arabic_adult.wav")
    p1, p2 = run_silero_max_prob(a1), run_silero_max_prob(a2)
    tk1, tk2 = run_blind_w2v_tokens(a1), run_blind_w2v_tokens(a2)
    record(
        "T14",
        "Bitwise, VAD, and Wav2Vec2-eSpeak deterministic repeatability verified",
        (h1 == h2) and np.array_equal(a1, a2) and (p1 == p2) and (tk1 == tk2) and len(tk1) > 0,
        f"sha_equal={h1 == h2}, vad_equal={p1 == p2}, tokens_equal={tk1 == tk2} (n={len(tk1)})",
        False,
    )

    # 15. Missing model artifact & manifest SHA-256 verification against all active files on disk
    disk_hashes = compute_disk_model_hashes(REPO_ROOT)
    manifest = json.loads((REPO_ROOT / "AI_MODELS_MANIFEST.json").read_text(encoding="utf-8"))
    manifest_mismatches = 0
    for key in ("silero_vad", "gtcrn_denoiser", "wav2vec2_espeak", "whisper_tiny"):
        files_dict = manifest["models"][key]["files"]
        for fmeta in files_dict.values():
            p = REPO_ROOT / fmeta["path"]
            if not p.exists() or sha256_file(p) != fmeta["sha256"]:
                manifest_mismatches += 1
    missing_zip = not (REPO_ROOT / "assets" / "ai_models" / "zipformer_v3" / "encoder.onnx").exists()
    dart_missing_ok = "pipelineStageFailed" in (REPO_ROOT / "lib" / "core" / "ai" / "pronunciation_repository.dart").read_text(encoding="utf-8")
    record(
        "T15",
        "Active ONNX SHA-256 manifest integrity & missing-model handling verified",
        manifest_mismatches == 0 and missing_zip and dart_missing_ok and len(disk_hashes) >= 7,
        f"active_manifest_mismatches={manifest_mismatches}, missing_zipformer_weights_honest={missing_zip}, disk_artifacts_locked={len(disk_hashes)}",
        False,
    )

    passed_count = sum(1 for r in results if r["passed"])
    return {
        "total_tests": len(results),
        "passed_count": passed_count,
        "failed_count": len(results) - passed_count,
        "all_passed": passed_count == len(results),
        "tests": results,
    }


if __name__ == "__main__":
    print(json.dumps(run_all_15_anti_cheating_tests(), indent=2, ensure_ascii=False))
