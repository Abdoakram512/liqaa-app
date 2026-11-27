# 12 — Honest Phase 0 Failures, Gaps & Risks

1. **Incomplete Candidate Access:** `Quran-Lab/zipformer_p-arabic-v3` is gated (`license:other`, weights missing); `SmartArabicSpeechTherapy` exposes 0 public HF models; `Arabic Little STT` HF URL returned 404; `L2-KSU` requires LDC agreement; `MAdel121/arabic-egy-cleaned` has `null` license on HF.
2. **Stage A (2,000) & Stage B (1,500) Corpora Not Yet Populated:** Phase 0 built schemas, leakage gates, and blind locks, NOT the full 3,500-sample evaluation sets (Stage A `2,000` is scheduled for Phase 1; Stage B `1,500` blind holdout evaluation is scheduled for Phase 4 after human verification).
3. **Android Device Benchmark Gap:** Desktop FFI checks ran cleanly, while real mid/low-tier Android device thermals, memory ceiling, and Oboe/NNAPI behavior are NOT yet benchmarked (`NOT VERIFIED` until a physical phone is tested).
4. **System `C:` Drive Scarcity (`{drives['C'].get('free_gb')} GB` free):** Keep heavy ML/Android caches redirected to `D:\YasserML`.
5. **Known Acoustic Fingerprinter Boundary:** Extreme low-SNR (`<0 dB`) augmentation can reduce waveform spectral similarity below `0.88`, making strict `parent_source_id` lineage logging mandatory alongside audio hashing.
