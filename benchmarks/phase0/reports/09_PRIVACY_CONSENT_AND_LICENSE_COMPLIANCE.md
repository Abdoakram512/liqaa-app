# 09 — Privacy, Consent & License Compliance

1. **Commercial App License Gate:**
   - **Cleared Open Commercial Licenses:** Silero VAD (MIT), GTCRN (MIT / Apache-2.0), DeepFilterNet3 (MIT/Apache-2.0), Wav2Vec2-eSpeak (Apache-2.0), Whisper Tiny & Large-v3-Turbo (MIT/Apache-2.0), MostafaMaroof Wav2Vec2 (Apache-2.0), Allophant (Apache-2.0), EgypTalk-ASR-v2 (CC-BY-4.0), Whisper-Small Egyptian (MIT), ASMDD (CC0), Abjad-Kids (MIT), Arabic Speech Corpus (CC-BY-4.0), EGYSpeak (CC-BY-4.0), MUSAN (CC-BY-4.0).
   - **Blocked / Restricted / Unverified:** `Quran-Lab/zipformer_p-arabic-v3` (`license:other`, manually gated), `AraYoungVoices` (unverified / NC-SA reported), `MAdel121/arabic-egy-cleaned` (`null` license field on HF), `L2-KSU` (`LDC2024S11` user agreement), `Arabic Little STT` (public HF 404), `SmartArabicSpeechTherapy` (no public release / `UNKNOWN`).
2. **Pediatric Voice PII & GitHub Hygiene:**
   - `.gitignore` excludes `benchmarks/audio/clips/`, `controlled/`, `results/samples/`, `_raw_downloads/`, `benchmarks/phase0/quarantine/`, `benchmarks/phase0/blind_vault/`, and `*.local.wav`.
   - `assets/audio_samples/` contains only 11 bundled diagnostic fixtures (synthetic TTS + 1 public sample + noise/silence). Zero raw pediatric clinical recordings are stored in Git.
   - Future Egyptian pediatric recordings require documented guardian written consent, anonymized `speaker_id` hashes, and storage strictly inside `D:\YasserML\` / encrypted vault.
