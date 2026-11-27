# 02 — Model Registry & Compatibility Audit

Machine-readable source: `benchmarks/phase0/MODEL_REGISTRY.json` (`14` entries = 13 Phase 0 candidates + 1 deprecated bundled RNNoise artifact).

## Summary Table
| `model_id` | Status | License | Commercial | Blind Phoneme | Size (MB) | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| `silero_vad_v4` | `LOCAL_BUNDLED_VERIFIED` | MIT | True | True | 2.102 | Local SHA-256 disk check + HF onnx-community/silero-vad metadata probe (rev e71cae96) |
| `gtcrn_denoiser` | `LOCAL_BUNDLED_VERIFIED` | MIT (GTCRN) / Apache-2.0 (sherpa-onnx) | True | True | 0.511 | Local SHA-256 disk check + GitHub license verification (Xiaobin-Rong/gtcrn MIT) |
| `rnnoise_legacy_bundled` | `LOCAL_DEPRECATED_UNUSED` | BSD-3-Clause | True | True | 0.973 | Local SHA-256 disk check + AiModelManager key alias inspection |
| `deepfilternet3` | `EXTERNAL_CANDIDATE_NOT_DOWNLOADED` | MIT OR Apache-2.0 (dual-licensed) | True | True | N/A (not downloaded) | GitHub repository license check (Rikorose/DeepFilterNet) |
| `wav2vec2_lv60_espeak_q4f16` | `LOCAL_BUNDLED_VERIFIED` | Apache-2.0 | True | True | 187.794 | Local SHA-256 disk check + HF facebook/wav2vec2-lv-60-espeak-cv-ft probe (rev ae45363b) |
| `zipformer_arabic_v3` | `PARTIAL_TOKENS_ONLY_WEIGHTS_MISSING_GATED` | other (HF card specifies license:other, gated manual approval) | False | True | 0.006 | Local SHA-256 check + HF API probe (Quran-Lab/zipformer_p-arabic-v3 rev db89c0fc -> gated: manual, license: other) |
| `zipformer_arabic_v2` | `PARTIAL_TOKENS_ONLY_WEIGHTS_MISSING` | UNKNOWN (likely matches Quran-Lab license:other) | False | True | 0.006 | Local SHA-256 check + comparison with zipformer_v3 |
| `mostafamaroof_wav2vec2_arabic_phoneme` | `REMOTE_HF_VERIFIED_NOT_DOWNLOADED` | Apache-2.0 | True | True | N/A (not downloaded) | HF API model_info (MostafaMaroof/wav2vec2-arabic-phoneme-asr rev 9c2bc0bc) |
| `kgnlp_allophant` | `REMOTE_HF_VERIFIED_NOT_DOWNLOADED` | Apache-2.0 | True | True | N/A (not downloaded) | HF API model_info (kgnlp/allophant rev ad69d315) |
| `whisper_tiny_int8` | `LOCAL_BUNDLED_VERIFIED` | Apache-2.0 (HF model card) / MIT (OpenAI Whisper code) | True | False | 98.81 | Local SHA-256 disk check + HF openai/whisper-tiny probe (rev 169d4a43) |
| `whisper_large_v3_turbo` | `REMOTE_HF_VERIFIED_NOT_DOWNLOADED` | MIT | True | False | N/A (not downloaded) | HF API model_info (openai/whisper-large-v3-turbo rev 41f01f3f) |
| `egyptalk_asr_v2` | `REMOTE_HF_VERIFIED_NOT_DOWNLOADED` | CC-BY-4.0 | True | False | N/A (not downloaded) | HF API model_info (NAMAA-Space/EgypTalk-ASR-v2 rev d23895cf) |
| `whisper_small_egyptian_arabic` | `REMOTE_HF_VERIFIED_NOT_DOWNLOADED` | MIT | True | False | N/A (not downloaded) | HF API model_info on both repos (1388a7fd and 562137b3) |
| `smart_arabic_speech_therapy_scorer` | `REMOTE_HF_SPACE_VERIFIED_NOT_DOWNLOADED` | MIT (Space cardData license:mit; runtime ASR dependencies e.g. NeMo/Whisper vary by choice) | True | False | 0.074 | HF Space API + Git LFS JSON/PTH resolution on MON3EMPASHA/SmartArabicSpeechTherapy (rev ef84267f) |

## Legacy Manifest Reconciliation Status
- **Legacy `AI_MODELS_MANIFEST.json` v1.1.0 flaws found prior to fix (7 issues):**
  1. Whisper Tiny encoder SHA-256 mismatch vs actual disk bytes (`12,937,772` bytes vs stale `12,937,966`).
  2. Active runtime `gtcrn_denoiser` omitted completely.
  3. Active runtime `wav2vec2_espeak` (`196,911,845` bytes) omitted completely.
  4. Deprecated `rnnoise` (`48kHz BFCC`) marked `ready: true`.
  5. `AI_MODEL_LICENSES.md` omitted GTCRN, Wav2Vec2-eSpeak, Abjad-Kids.
- **Post-Reconciliation Status (`v2.0.0-phase0`):** Remaining reconciliation issues = **0**.
