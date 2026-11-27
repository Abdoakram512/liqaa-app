# 12 — Honest Phase 0 Failures, Gaps & Risks

1. **Incomplete Candidate Access:** `Quran-Lab/zipformer_p-arabic-v3` is gated (`license:other`, weights missing); `SmartArabicSpeechTherapy` exposes 0 public HF models; `Arabic Little STT` HF URL returned 404; `L2-KSU` requires LDC agreement; `MAdel121/arabic-egy-cleaned` has `null` license on HF.
2. **Stage A (2,000) & Stage B (1,500) Corpora Not Yet Populated:** Phase 0 built schemas, leakage gates, and blind locks, NOT the full 3,500-sample evaluation sets (left intentionally to Phase 3 acquisition after human verification).
3. **Android Device Benchmark Gap:** Desktop FFI checks ran cleanly, while real mid/low-tier Android device thermals, memory ceiling, and Oboe/NNAPI behavior are NOT yet benchmarked in Phase 0.
4. **System `C:` Drive Scarcity (`2.07 GB` free):** Requires user cleanup before installing large Windows SDK updates or Android NDK caches.
5. **Known Acoustic Fingerprinter Boundary:** Extreme low-SNR (`<0 dB`) augmentation can reduce waveform spectral similarity below `0.88`, making strict `parent_source_id` lineage logging mandatory alongside audio hashing.
