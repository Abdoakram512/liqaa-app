# LIQAA — AI Model Licenses and Provenance

## 1. Compliance Statement

All AI models, datasets, and pretrained weights incorporated into or evaluated by the LIQAA application are strictly open-source, permissive, or freely licensed for educational, non-commercial, and research use. **Zero proprietary, paid, or cloud-metered technologies are employed.**

---

## 2. Model License Inventory

### 2.1 Silero VAD v4
- **Author / Maintainer:** Silero Team ([snakers4](https://github.com/snakers4/silero-vad))
- **License:** MIT License
- **Terms:** Permissive. Permits free use, modification, distribution, private use, and sublicensing with attribution.
- **Commercial Use:** Allowed (LIQAA is strictly non-commercial).
- **File:** `assets/ai_models/silero/silero_vad.onnx` (2.1 MB)
- **SHA256:** `f6f4407b41e05e277e7f5cfd9b9ae957b1dfe763c6076a934734c0b448e09b31`

### 2.2 RNNoise
- **Author / Maintainer:** Jean-Marc Valin / Xiph.Org Foundation ([xiph/rnnoise](https://github.com/xiph/rnnoise))
- **License:** BSD 3-Clause "New" or "Revised" License
- **Terms:** Permissive. Redistribution and use in source and binary forms, with or without modification, are permitted provided that copyright notice and conditions are met.
- **File:** `assets/ai_models/rnnoise/rnnoise.onnx` (0.97 MB)
- **SHA256:** `22123b85825b413e7c97de8334c6b609f0c6aa1cd5290ab672bb1b85bae20403`

### 2.3 Sherpa-ONNX Whisper Tiny Multilingual (ASR & Phonetics)
- **Author / Maintainer:** OpenAI / csukuangfj ([k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx))
- **License:** MIT License
- **Terms:** Permissive open-source license. Offline on-device inference for speech recognition in Arabic (`ar`) and 98 other languages.
- **Files:**
  - `tiny-encoder.int8.onnx` (12.34 MB, SHA256: `418fa553250fbdfd4d46cfb70503f5727027ae45c6198f121df0c9e6dcf3ae0a`)
  - `tiny-decoder.int8.onnx` (85.69 MB, SHA256: `d2fece8dd42771f1df975c6c0445770d0c292bf7547c2cae04a6c0cc57540925`)
  - `tiny-tokens.txt` (0.78 MB, SHA256: `b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126`)
- **Total Footprint:** 98.8 MB

### 2.4 Zipformer Arabic V3 & V2 Tokens
- **Author / Maintainer:** Quran-Lab Team & Muno459
- **License:** NPL-1.3 (Non-Profit) / Free Non-Commercial Research
- **Files:** Phoneme unit dictionaries and token vocabularies (`tokens.txt`, `phoneme_units.json`) in `assets/ai_models/zipformer_v3/`.

---

## 3. Dataset Provenance: ASMDD (Arabic Speech Mistakes Detection Dataset)

- **Citation:** "ASMDD: Arabic Speech Mistakes Detection Dataset", Mendeley Data, V1, doi: 10.17632/x54dg53rmr.1
- **Authors:** Department of Information Systems / Speech Pathology Collaborators, Cairo University & Ain Shams University.
- **License:** CC0 1.0 Universal (Public Domain Dedication).
- **Terms:** Dedicated to public domain worldwide without copyright restriction.
- **Content:** Verified child speech recordings and clinical substitution patterns from 100 Egyptian children aged 2 to 8.
- **Application in LIQAA:** Clinical substitution rules, phonetic alignment penalties, and speech therapy guidance.
