# DATASET PROVENANCE, PRIVACY & PREPROCESSING STRESS REPORT

## 1. Benchmark Corpus Composition (`benchmarks/audio/manifest.jsonl`)

The independent evaluation benchmark comprises **100 unique audio clips** totaling **`212.90 seconds`** across **61 distinct speaker IDs** plus silence and environmental noise fixtures, strictly separated from synthetic TTS assets (`benchmarks/audio/controlled_manifest.jsonl`).

| Category | Count | Source Datasets | Age Group | Dialect(s) | Ground Truth Type |
| :--- | :---: | :--- | :--- | :--- | :--- |
| `correct_pediatric` | 20 | `ASMDD` (10), `Abjad-Kids` (10) | `2–8 yrs` (10), `3–12 yrs` (10) | Egyptian Arabic (10), Multi-Dialect (10) | Expert / dataset word label + IPA |
| `genuine_pediatric_errors` | 20 | `ASMDD` (`_N` suffix, 20) | `2–8 yrs` | Egyptian Arabic | Expert clinical mispronunciation label (`_N`) |
| `unrelated_word_pediatric` | 10 | `Abjad-Kids` (10) | `3–12 yrs` | Multi-Dialect | True spoken word differs from prompt word |
| `quiet_weak_pediatric` | 10 | `Abjad-Kids` (10) | `3–12 yrs` | Multi-Dialect | Lowest-RMS pediatric clips (`0.0059–0.0193`) |
| `noisy_pediatric` | 10 | `ASMDD` (10) | `2–8 yrs` | Egyptian Arabic | Real nursery/classroom ambient speech |
| `adult_arabic_speech` | 10 | `egyptian-arabic-speech` (4), `arabic_speech_corpus` (3), `MASC-Arabic` (3) | `adult` | Egyptian (4), MSA (3), Multi-Dialect (3) | Word & phonetic transcripts (`tunis-ai` PHON) |
| `silence_near_silence` | 5 | `Controlled Silence / Noise Floor Fixtures` | `n/a` | `n/a` | Exact `0.0` & noise-floor RMS (`0.00024–0.00054`) |
| `environmental_noise` | 5 | `MUSAN` (`bilguun/musan-noise`) | `n/a` | `n/a` | Genuine non-speech noise (fan, traffic, babble, crowd, handling) |
| `isolated_consonants_syllables` | 5 | `Abjad-Kids` (5) | `3–12 yrs` | Multi-Dialect | Isolated letter/phoneme names (`كاف`, `سين`, `راء`, `حاء`, `ألف`) |
| `difficult_edge_cases` | 5 | `Abjad-Kids` (4), `ASMDD` (1) | `2–12 yrs` | Multi-Dialect (4), Egyptian (1) | Emphatics (`/dˤ, tˤ/`), interdental `/θ, ð/`, clipped peak (`1.0`) |
| **Total Real/Diagnostic** | **100** | **7 verified sources** | **80 pediatric / 10 adult / 10 non-speech** | **45 EG / 42 Multi / 3 MSA / 10 n/a** | `manifest.jsonl` + `ground_truth.csv` |

### Vocabulary Dictionary Overlap Audit
Of the 100 manifest items, **`23`** target words appear directly in `assets/pronunciation/egyptian_arabic_dictionary.json` (`in_dictionary=True`) while **`77`** are out-of-dictionary diagnostic words or non-speech items (`in_dictionary=False`), preventing closed-set memorization.

---

## 2. Dataset Licensing, Ethics & Privacy Controls

| Dataset | Exact Identifier / Source | Verified License | Privacy / Anonymization Action | Redistributed to Git? |
| :--- | :--- | :--- | :--- | :--- |
| **ASMDD** | `10.17632/x54dg53rmr.1` (Aly et al., 2021, Mendeley Data) | **CC0 1.0** | Original directory UUIDs stripped; speakers mapped to `spk_asmdd_01..XX` | **No** (`.gitignore` excludes raw `.wav`; fetched via `fetch_benchmark_dataset.py`) |
| **Abjad-Kids** | `Aziz-snoubra/Abjad-Kids` (Hugging Face) | **MIT License** | Original filenames containing child first names removed from copied clips (`S001.wav..S100.wav`) and mapped to `spk_abjad_XXX` | **No** (`.gitignore` excludes raw `.wav`) |
| **Arabic Speech Corpus** | `tunis-ai/arabic_speech_corpus` (Halabi) | **CC-BY-4.0** | Adult studio speaker; attribution preserved | **No** |
| **MASC-Arabic** | `MohamedRashad/MASC-Arabic` | **CC-BY-4.0** | Adult speaker; attribution preserved | **No** |
| **Egyptian Arabic Speech** | `ammarthabet/egyptian-arabic-speech` | **Open HF Dataset** (untagged license) | Adult dialogue excerpts; raw `.wav` NOT committed to GitHub to respect unclear redistribution scope | **No** |
| **MUSAN Noise** | `bilguun/musan-noise` / OpenSLR `SLR17` | **CC-BY-4.0** | Free-sound / SoundBible notices preserved | **No** |

> [!NOTE]
> All raw audio files under `benchmarks/audio/clips/*.wav`, `benchmarks/audio/controlled/*.wav`, and `benchmarks/results/samples/*.wav` are excluded via `.gitignore` to keep the repository lightweight and strictly protect child speaker privacy and third-party dataset redistribution boundaries. Anyone can deterministically reproduce the corpus via [fetch_benchmark_dataset.py](file:///e:/Flutter%20Projects/liqaa_app/benchmarks/scripts/fetch_benchmark_dataset.py).

---

## 3. Separate Controlled & Synthetic Sets (`controlled_manifest.jsonl`)

Strictly excluded from all 100 real-world summary rates:
- **18 Paired Clean + MUSAN Noisy Mixtures:** 3 real clean pediatric words (`S011 كورة`, `S012 كلب`, `S013 أرنب`) mixed at **`-5, 0, 5, 10, 15, 20 dB` SNR** against `fan_appliance_noise`, `ambient_street_traffic`, and `household_television_babble`.
- **5 Controlled Synthetic Edge Neural TTS Fixtures (`assets/audio_samples/`):** `correct_kora.wav`, `error_tora.wav`, `correct_arnab.wav`, `error_anlab.wav`, `word_madrasa.wav` used strictly for deterministic minimal-pair and anti-cheating verification.

---

## 4. Signal Characteristics & AudioPreprocessor 20-Case Stress Suite

In the 100-sample corpus, raw formats span **`97` x `PCM 16-bit 1ch`** (`16/24/44.1/48 kHz`) and **`3` x `PCM 32-bit 1ch`** (`MASC-Arabic`), with **`1` clipped sample** (`S097 ضابط`, `peak=1.0`).  
`AudioPreprocessor.normalizeWav` was independently stress-tested across **20 synthetic edge-case containers** ([preprocessing_stress.json](file:///e:/Flutter%20Projects/liqaa_app/benchmarks/results/preprocessing_stress.json)):

| Stress Group | Tested Cases | Outcome | Observed Behavior |
| :--- | :--- | :---: | :--- |
| **Sample Rates** | `8 kHz`, `16 kHz`, `22.05 kHz`, `24 kHz`, `44.1 kHz`, `48 kHz` | **6 / 6 PASS** | Linear resampling produces exact `9600` (`600 ms`) or `8000` (`500 ms`) frames at `16 kHz`; RMS `0.281–0.283` |
| **Bit Depths & Codecs** | `PCM8`, `PCM24`, `PCM32 Int`, `IEEE Float32`, Stereo `2ch -> 1ch` | **5 / 5 PASS** | Accurate mono normalization; `RMS ~0.281–0.283`, `0` clipping |
| **Container & Amplitude Edges** | Extra `LIST` metadata chunk before `data`, `40 ms` ultra-short, `8000 ms` long, `clipped_high` (`4280` clipped samples reported), `low_amp_speech` (`RMS=0.00353`, `peak=0.00500`), `dc_offset +0.35` | **5 / 5 PASS** | Metadata accurately parsed; `valid_out_wav=true`; low-amp speech preserved without truncation |
| **Malformed / Non-WAV Rejection** | `truncated_wav_30b`, `corrupted_header`, `missing_header_pcm`, `empty_bytes` | **4 / 4 PASS** | All 4 threw `InvalidAudioFormatException` cleanly without crashing native FFI |
| **Total Stress Suite** | **20 adversarial & format edge cases** | **20 / 20 (100%)** | Zero crashes, zero silent header corruption |
