# Benchmark Dataset Provenance & Licensing

This document records all audio sources used in the independent 100-sample LIQAA / Yasser AI benchmark (`benchmarks/audio/manifest.jsonl`) and separate controlled ablation/noise fixtures (`benchmarks/audio/controlled_manifest.jsonl`).

## 1. Datasets Used & Verified Licenses

1. **ASMDD — Arabic Speech Mispronunciation Detection Dataset**
   - **Identifier / DOI:** `10.17632/x54dg53rmr.1` (Salah A. Aly, Abdelrahman Salah, Hesham M. Eraqi, 2021)
   - **URL:** `https://data.mendeley.com/datasets/x54dg53rmr/1` (`arXiv:2111.01136`)
   - **License:** **CC0 1.0 Universal Public Domain Dedication**
   - **Population:** Egyptian Arabic-speaking children aged **2–8 years**, recorded across nursery-school environments (`44.1 kHz`, 32-bit mono WAV originally), pronouncing top 100 frequent Arabic words in Egyptian dialogue. Expert human listeners annotated segmental mispronunciations with `_N` suffixes.
   - **Privacy Handling:** Folder UUIDs mapped to anonymous IDs (`spk_asmdd_XX`).

2. **Abjad-Kids — Arabic Speech Classification Dataset for Primary Education**
   - **Repository:** `Aziz-snoubra/Abjad-Kids` on Hugging Face
   - **URL:** `https://huggingface.co/datasets/Aziz-snoubra/Abjad-Kids`
   - **License:** **MIT License**
   - **Population:** Arabic-speaking children aged **3–12 years** pronouncing Arabic vocabulary words, numbers, colors, and isolated Arabic alphabet names/sounds.
   - **Privacy & Anonymization:** Original filenames include child first names; all benchmark copies are stored under anonymized IDs (`S001.wav`..`S100.wav`) and `spk_abjad_XXX` identifiers with zero child names retained.

3. **Arabic Speech Corpus (`tunis-ai/arabic_speech_corpus`)**
   - **URL:** `https://huggingface.co/datasets/tunis-ai/arabic_speech_corpus`
   - **License:** **CC-BY-4.0** (Attribution: Nawar Halabi, University of Southampton)
   - **Role:** Modern Standard Arabic adult speech with independent phonetic & orthographic annotations.

4. **MASC-Arabic (`MohamedRashad/MASC-Arabic`)**
   - **URL:** `https://huggingface.co/datasets/MohamedRashad/MASC-Arabic`
   - **License:** **CC-BY-4.0**
   - **Role:** Multi-dialect adult Arabic speech recordings with verified transcripts.

5. **Egyptian Arabic Speech (`ammarthabet/egyptian-arabic-speech`)**
   - **URL:** `https://huggingface.co/datasets/ammarthabet/egyptian-arabic-speech`
   - **License:** Public Hugging Face dataset (Egyptian Arabic dialogue transcripts & audio; non-restricted research validation).
   - **Role:** Adult Egyptian Arabic speech samples.

6. **MUSAN Noise Corpus (`bilguun/musan-noise` / OpenSLR SLR17)**
   - **URL:** `https://www.openslr.org/17/` and `https://huggingface.co/datasets/bilguun/musan-noise`
   - **License:** **CC-BY-4.0** (free-sound public domain & sound-bible Creative Commons attributions preserved in `musan-noise` `LICENSE` files).
   - **Role:** Genuine environmental non-speech noises (fans, traffic, babble, household ambient, handling) for both Category 8 non-speech rejection and separate controlled SNR mixing (`controlled_manifest.jsonl`).

7. **Controlled Diagnostic & Synthetic Fixtures (Strict Separation)**
   - Silence (`assets/audio_samples/silence.wav`) and near-silence signal-floor tests (`S081..S085`).
   - Synthetic Edge Neural TTS Arabic minimal pairs (`correct_kora.wav`, `error_tora.wav`, `correct_arnab.wav`, `error_anlab.wav`, `word_madrasa.wav`) kept **strictly outside** the 100 real-world manifest in `controlled_manifest.jsonl`.

## 2. Reproducible Acquisition
Run from the repository root:
```powershell
python benchmarks/scripts/fetch_benchmark_dataset.py
```
This script verifies RIFF/WAVE integrity, computes SHA-256 checksums, extracts raw acoustic stats without executing evaluated models, and writes `manifest.jsonl`, `ground_truth.csv`, and `controlled_manifest.jsonl`.
