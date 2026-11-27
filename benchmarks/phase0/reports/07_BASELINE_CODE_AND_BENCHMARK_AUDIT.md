# 07 — Baseline Code & Historical Benchmark Audit

## Verified Code Architecture (`lib/core/ai/`)
- **`PhonemeRecognitionEngine` (`phoneme_recognition_engine.dart`):** Confirmed strictly blind (`recognizePhonemesDetailed` accepts `Float32List` audio only; zero target-word hints). Enforces 16,000-sample startup readiness probe, `_minWav2VecSamples = 1600`, `Platform.isAndroid` optimization guards.
- **`PronunciationEvaluator` (`pronunciation_evaluator.dart`):** Separates scoring from acoustic decoding using Wagner-Fischer DP alignment + clinical Egyptian Arabic substitution rules.
- **`PronunciationRepository` (`pronunciation_repository.dart`):** Distinguishes recording failures (`recordingFailed`), invalid WAV headers (`invalidAudioFormat`), dead digital silence (`rawPeak < 0.002`), noisy room aborts (`rawSnr < 2.0 && rawRms > 0.08`), missing ONNX models (`modelInitFailed`), and speech rejection cleanly.
- **`AiModelManager` (`ai_model_manager.dart`):** Reconciled in Phase 0 with `AI_MODELS_MANIFEST.json` v2.0.0-phase0 (remaining manifest discrepancies: **0**).

## Historical 100-Sample Benchmark Baseline (Carried From Audited Repo Report, Pre-Phase 1)
- Prior `benchmarks/reports/MASTER_AI_BENCHMARK_REPORT.md` documented real failure modes honestly: pediatric correct pass `1/20 (5%)`, adult MSA PER `14.79%` vs pediatric PER `71.88%`, Silero VAD `0.9831 F1`, and GTCRN clean-speech consonant attenuation gated at `<14 dB`.
- Those 100 historical clips + 23 controlled entries belong STRICTLY to Stage A / audit history and are excluded from Stage B Blind Holdout.
