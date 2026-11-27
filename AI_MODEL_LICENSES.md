# AI Model & Dataset Licenses / Provenance

> Reconciled under **YASSER AI SYSTEM — PHASE 0 (AI Integrity & Dataset Governance)**.
> See `benchmarks/phase0/MODEL_REGISTRY.json` and `benchmarks/phase0/DATASET_REGISTRY.json` for full machine-readable verification records.

## 1. Bundled Runtime Models (`assets/ai_models/`)

| Model | Purpose | Upstream Source | License | Commercial Status | Notes |
| --- | --- | --- | --- | --- | --- |
| **Silero VAD v4/v5** | Voice Activity Detection | [snakers4/silero-vad](https://github.com/snakers4/silero-vad) / [onnx-community/silero-vad](https://huggingface.co/onnx-community/silero-vad) | **MIT** | Permitted | Dual v4/v5 stateful ONNX verified locally |
| **GTCRN Speech Enhancement** | 16kHz Neural Noise Suppression | [Xiaobin-Rong/gtcrn](https://github.com/Xiaobin-Rong/gtcrn) / [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | **MIT / Apache-2.0** | Permitted | Active production denoiser (`gtcrn_simple.onnx`) |
| **Wav2Vec2-LV60-eSpeak-CV-FT (Q4F16)** | Blind IPA Phoneme CTC Recognition | [facebook/wav2vec2-lv-60-espeak-cv-ft](https://huggingface.co/facebook/wav2vec2-lv-60-espeak-cv-ft) | **Apache-2.0** | Permitted | 187.79 MB quantized ONNX; zero target-word hints |
| **OpenAI Whisper Tiny (INT8)** | Auxiliary Arabic Word STT | [openai/whisper-tiny](https://huggingface.co/openai/whisper-tiny) / `sherpa-onnx` | **MIT / Apache-2.0** | Permitted | Diagnostic STT only; exact SHA-256 reconciled in Phase 0 |
| **RNNoise (Legacy ONNX)** | Deprecated 48kHz BFCC denoiser | [xiph/rnnoise](https://github.com/xiph/rnnoise) | **BSD-3-Clause** | Permitted (Unused) | Not loaded at runtime; scheduled for asset cleanup |
| **Zipformer Arabic V3 / V2 (Tokens only)** | Token files (`weights missing`) | [Quran-Lab/zipformer_p-arabic-v3](https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3) | **`other` (Manually Gated)** | **Blocked / Unverified** | Weights absent; requires upstream permission before use |

## 2. Candidate Benchmark Models (External / Not Bundled)

- **DeepFilterNet3** ([Rikorose/DeepFilterNet](https://github.com/Rikorose/DeepFilterNet)) — Dual **MIT OR Apache-2.0** (commercial permitted).
- **MostafaMaroof/wav2vec2-arabic-phoneme-asr** — **Apache-2.0** (commercial permitted; trained on `tunis-ai/arabic_speech_corpus` & `IqraEval/Iqra_train` — contaminated for ASC tests).
- **kgnlp/allophant** — **Apache-2.0** (commercial permitted).
- **OpenAI Whisper Large-v3-Turbo** — **MIT** (server/teacher only; too heavy for mobile).
- **NAMAA-Space/EgypTalk-ASR-v2** — **CC-BY-4.0** (attribution required).
- **MAdel121 & ismaeel-farag/whisper-small-egyptian-arabic** — **MIT** (`MAdel121` model explicitly trained on `MAdel121/arabic-egy-cleaned`).
- **Smart Arabic Speech Therapy / Nateq Pediatric Phoneme Scorer** ([HF Space MON3EMPASHA/SmartArabicSpeechTherapy](https://huggingface.co/spaces/MON3EMPASHA/SmartArabicSpeechTherapy)) — **MIT** (`models/phoneme_scorer_latest.pth`, 78,004 bytes, trained on 4,235/1,059 ASMDD split per `model_metadata_latest.json` & `ASMDD.csv`; relies on upstream ASR aligner e.g. FastConformer/Whisper — **contaminated for ASMDD clean evaluation**).

## 3. Referenced & Benchmark Datasets

| Dataset | Source | License | Commercial / Usage Rule |
| --- | --- | --- | --- |
| **ASMDD** | [Mendeley 10.17632/x54dg53rmr.1](https://data.mendeley.com/datasets/x54dg53rmr/1) | **CC0 1.0** | Public domain pediatric Egyptian Arabic word dataset |
| **Abjad-Kids** | [Aziz-snoubra/Abjad-Kids](https://huggingface.co/datasets/Aziz-snoubra/Abjad-Kids) | **MIT** | Pediatric isolated letters and vocabulary |
| **Arabic Speech Corpus** | [tunis-ai/arabic_speech_corpus](https://huggingface.co/datasets/tunis-ai/arabic_speech_corpus) | **CC-BY-4.0** | Adult MSA studio speech; attribution required |
| **MASC-Arabic** | [MohamedRashad/MASC-Arabic](https://huggingface.co/datasets/MohamedRashad/MASC-Arabic) | **CC-BY-4.0** | Multi-dialect Arabic speech; attribution required |
| **EGYSpeak** | [MohamedGomaa30/EGYSpeak](https://huggingface.co/datasets/MohamedGomaa30/EGYSpeak) | **CC-BY-4.0** | Egyptian Arabic corpus; attribution required |
| **MUSAN Noise** | [OpenSLR SLR17](https://www.openslr.org/17/) | **CC-BY-4.0** | Environmental background noise fixtures |
| **arabic-egy-cleaned** | [MAdel121/arabic-egy-cleaned](https://huggingface.co/datasets/MAdel121/arabic-egy-cleaned) | **UNKNOWN (`null` on HF)** | Resolve license before commercial training |
| **AraYoungVoices** | Literature (`151.72h`) | **UNKNOWN / NC-SA reported** | Non-commercial / unverified repo — research analysis only |
| **Arabic Little STT** | [arXiv:2510.23319](https://arxiv.org/abs/2510.23319) | **UNKNOWN (HF 404)** | Classroom Levantine child ASR; public mirror unreachable |
| **L2-KSU** | [LDC2024S11](https://catalog.ldc.upenn.edu/LDC2024S11) | **LDC User Agreement** | Restricted; manual LDC authorization required |
| **Private Egyptian Child Cohort** | Future local encrypted collection (`D:\YasserML`) | **Consented Clinical / Product** | Written parental consent required; NEVER commit audio to GitHub |
