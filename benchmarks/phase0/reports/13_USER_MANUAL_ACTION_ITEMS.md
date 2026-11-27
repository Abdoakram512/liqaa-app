# 13 — User Manual Action Items Before Phase 1 / Phase 4

1. **Maintain Disk Space on `C:` Drive:** Avoid placing ML/HF/torch/build caches on `C:`; keep `>= 15 GB` buffer before heavy Android/ML workflows (`D:\YasserML` holds primary ML data).
2. **Clarify External Restricted Assets:**
   - Decide whether to apply for `Quran-Lab/zipformer_p-arabic-v3` gated HF access & verify commercial licensing (`license:other`), or exclude Quran-Lab Zipformer from commercial roadmap candidates.
   - Obtain `L2-KSU` (`LDC2024S11`) via LDC membership if needed for L2/Arabic evaluation.
   - Contact authors if `Arabic Little STT` or `SmartArabicSpeechTherapy` weights are desired for academic comparison.
3. **Pediatric Data Governance Approval:** Finalize Egyptian clinical/parental written consent form before collecting the private Egyptian pediatric cohort (`future_egyptian_pediatric_private_collection`) into `D:\YasserML`.
4. **Physical Android Target Device Testing:** Connect an Android test phone over USB (`adb`) to verify on-device Picture Naming Game recording, audio focus, and ONNX runtime behavior.
