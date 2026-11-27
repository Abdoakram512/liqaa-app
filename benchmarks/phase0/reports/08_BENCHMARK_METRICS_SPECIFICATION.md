# 08 — Reusable Benchmark Metrics Specification

Implemented and unit-tested in `benchmarks/phase0/metrics_engine.py`:
- **VAD (`compute_vad_metrics`):** TP/FP/TN/FN, speech recall + Wilson 95% CI, non-speech specificity + Wilson CI, false-alarm rate, precision, F1, balanced accuracy.
- **Noise Suppression (`compute_noise_suppression_metrics`):** Input/output SI-SDR (dB), mean SI-SDR gain, clean speech waveform preservation correlation.
- **STT (`compute_stt_metrics`):** Arabic normalization (`Alef`, `Teh Marbuta`, diacritics), WER, CER, normalized exact match + Wilson CI, silence/noise hallucination rate + Wilson CI.
- **Phoneme (`compute_phoneme_metrics`):** Exact Levenshtein PER, S/D/I breakdown, micro precision/recall/F1, sequence exact match + Wilson CI, top confusion matrix pairs.
- **Pronunciation Assessment (`compute_assessment_metrics`):** True acceptance rate, true error rejection rate, FAR, FRR, balanced accuracy, abstention rate, speaker-level macro accuracy (prevents multi-clip speakers distorting sample KPIs), Brier calibration score (`null` when uncalibrated), Wilson 95% CIs.
- **Runtime (`compute_runtime_metrics`):** Cold first latency, P50/P95 latency, mean RTF, peak RAM (MB).
