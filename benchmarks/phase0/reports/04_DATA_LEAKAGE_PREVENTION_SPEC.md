# 04 — Data Leakage Prevention Specification

Implementation: `benchmarks/phase0/leakage_engine.py` + `benchmarks/phase0/MODEL_DATASET_CONTAMINATION_MATRIX.csv` (`140` cells).

## Multi-Layer Detection Architecture
1. **Exact File Hash (`raw_file_sha256`):** Blocks byte-identical or renamed WAV duplicates across splits.
2. **Canonical PCM Hash (`canonical_pcm_sha256`):** Resamples to 16kHz mono, strips DC offset, peak-normalizes, quantizes PCM16 so header-edited or gain-scaled copies match identically.
3. **Acoustic Spectral Fingerprint (`cosine >= 0.88`, min duration ratio `0.35`, silence excluded):** Detects resampled, trimmed/silence-padded, and moderate-noise augmented variants. Known limitation: near-silent floors excluded to avoid false positives; heavy `<0 dB` noise attenuation requires mandatory `parent_source_id` lineage enforcement.
4. **Graph & Metadata Isolation:** Enforces disjoint `speaker_id`, `session_id`, `parent_source_id` augmentation trees, cross-dataset identity, and multi-word transcript overlap alerts.

## Real Audit of Existing Project Manifests (`123` Local WAVs)
- **Files hashed:** `123` / `123` (`100` historical benchmark clips + `23` controlled entries).
- **Intra-100 Exact/Canonical/Speaker Overlaps:** `0` exact, `0` canonical, `0` speaker overlaps.
- **Derived Lineage & Cross-Set Acoustic Catches:** `3` augmentation lineages (`S011`, `S012`, `S013` paired with `MIX_*dB`) and `57` acoustic similarity links (correctly flagging clean+MUSAN noisy copies and TTS minimal-pair carriers), `24` quarantined derived IDs.

## High-Risk Model-Dataset Overlaps Detected
- `MostafaMaroof/wav2vec2-arabic-phoneme-asr` × `tunis-ai/arabic_speech_corpus` -> **`DIRECT_OVERLAP`** (HF tag verified).
- `MAdel121/whisper-small-egyptian-arabic` × `MAdel121/arabic-egy-cleaned` -> **`DIRECT_OVERLAP`** (HF tag verified).
- Total non-`CLEAN_VERIFIED` matrix cells requiring exclusion/caution: `90`.
