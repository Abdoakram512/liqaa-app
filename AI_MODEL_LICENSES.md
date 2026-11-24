# LIQAA — AI Model Licenses and Provenance

## 1. Compliance Statement

All AI models, datasets, and pretrained weights incorporated into or evaluated by the LIQAA application are strictly open-source, permissive, or freely licensed for educational, non-commercial, and research use. **Zero proprietary, paid, or cloud-metered technologies are employed.**

---

## 2. Model License Inventory

### 2.1 Silero VAD v4
- **Author / Maintainer:** Silero Team ([snakers4](https://github.com/snakers4/silero-vad))
- **License:** MIT License
- **Terms:** Permissive. Permits free use, modification, distribution, private use, and sublicensing with attribution.
- **Commercial Use:** Allowed (though LIQAA is strictly non-commercial).
- **Download Source:** [https://raw.githubusercontent.com/snakers4/silero-vad/master/src/silero_vad/data/silero_vad.onnx](https://raw.githubusercontent.com/snakers4/silero-vad/master/src/silero_vad/data/silero_vad.onnx)

### 2.2 RNNoise
- **Author / Maintainer:** Jean-Marc Valin / Xiph.Org Foundation ([xiph/rnnoise](https://github.com/xiph/rnnoise))
- **License:** BSD 3-Clause "New" or "Revised" License
- **Terms:** Permissive. Redistribution and use in source and binary forms, with or without modification, are permitted provided that copyright notice and conditions are met.
- **Download Source:** [https://huggingface.co/niobures/RNNoise](https://huggingface.co/niobures/RNNoise)

### 2.3 Zipformer Arabic V3
- **Author / Maintainer:** Quran-Lab Team ([Quran-Lab/zipformer_p-arabic-v3](https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3))
- **License:** Quran-Lab No-Profit License 1.3 (NPL-1.3)
- **Terms:** Free for non-profit, educational, and academic research purposes. Commercial redistribution without prior consent is prohibited.
- **LIQAA Compatibility:** 100% Compliant — LIQAA is a completely free, non-commercial educational project for Egyptian children.
- **Access:** Gated on Hugging Face (requires accepting terms via free Hugging Face account).

### 2.4 Zipformer Arabic V2
- **Author / Maintainer:** Muno459 ([Muno459/zipformer_p-arabic-v2](https://huggingface.co/Muno459/zipformer_p-arabic-v2))
- **License:** Free Non-Commercial Research License
- **Terms:** Unrestricted non-commercial academic and developmental deployment.
- **LIQAA Compatibility:** 100% Compliant.
- **Access:** Gated on Hugging Face.

### 2.5 Nabra 82M & Moonshine Tiny
- **Author / Maintainer:** k2-fsa / csukuangfj / Moonshine AI
- **License:** Apache License 2.0 / MIT License
- **Terms:** Permissive open-source licenses.
- **Download Source:** [https://huggingface.co/csukuangfj/nabra-82m-arabic-int8](https://huggingface.co/csukuangfj/nabra-82m-arabic-int8)

---

## 3. Dataset Provenance: ASMDD (Arabic Speech Mistakes Detection Dataset)

- **Citation:** "ASMDD: Arabic Speech Mistakes Detection Dataset", Mendeley Data, V1, doi: 10.17632/x54dg53rmr.1
- **Authors:** Department of Information Systems / Speech Pathology Collaborators, Cairo University & Ain Shams University.
- **License:** CC0 1.0 Universal (Public Domain Dedication).
- **Terms:** The work is dedicated to the public domain worldwide. Anyone may copy, modify, distribute, and perform the work, even for commercial purposes, without asking permission.
- **Content:** 100 high-frequency Arabic words pronounced by 100 Egyptian children (aged 2 to 8), manually verified and categorized by speech-language pathologists (SLPs).
- **Usage in LIQAA:** Serves as the clinical baseline for the Egyptian Arabic phonetic substitution rules embedded into `assets/pronunciation/egyptian_arabic_dictionary.json` and the testing benchmark.
