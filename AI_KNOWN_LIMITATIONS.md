# LIQAA — AI Subsystem Known Limitations and Scope Boundaries

## 1. Regulatory and Medical Disclaimer

> [!IMPORTANT]
> **LIQAA is an educational game and practice aid, not a certified medical or clinical diagnostic instrument.**
> It does not diagnose speech sound disorders (SSD), childhood apraxia of speech (CAS), or dysarthria, and does not replace evaluation and intervention by licensed Speech-Language Pathologists (SLPs).

---

## 2. Identified Technical Limitations

### 2.1 Acoustic Model Limitations
1. **Adult-Trained Acoustic Backbones:**
   - Both Zipformer V2 and V3 are primarily trained on adult speakers. While pediatric acoustic margin compensation reduces error, children younger than 3.5 years exhibiting extreme formant shifts ($F_0 > 450\text{ Hz}$) may experience occasional phoneme misalignments.
2. **Dialectal Variation Within Egypt:**
   - The primary dictionary reflects Greater Cairo / Cairene Egyptian Arabic. Children speaking Upper Egyptian (Sa'idi) or Alexandria/Bedouin vernaculars (who retain the hard $[q]$ or alternate vowel shifts) may be flagged for dialectal features rather than pathology. The dictionary allows both $[q]$ and $[ʔ]$ for target words like قلم.
3. **Fricative Attenuation Under Aggressive Noise Filtering:**
   - Standard neural denoisers like RNNoise can inadvertently treat soft high-frequency child fricatives ($[s], [\theta], [\hbar]$) as stationary noise if the child whispers or speaks below $-35\text{ dBFS}$. For this reason, the default state prioritizes clean raw audio when ambient SNR is satisfactory.

### 2.2 Environmental & Device Limitations
1. **Budget Device Microphones:**
   - Entry-level Android smartphones frequently employ aggressive hardware-level automatic gain control (AGC) or low-quality electret microphones with significant frequency roll-off above 6 kHz. This can reduce recognition accuracy for dental/palatal fricatives.
2. **Background Speech Intrusion:**
   - Silero VAD detects presence of human speech, but cannot differentiate between the child speaking and a parent speaking simultaneously in the background. Testing must occur with only the child speaking near the microphone.

### 2.3 Repository Gating on Hugging Face
- Both `Muno459/zipformer_p-arabic-v2` and `Quran-Lab/zipformer_p-arabic-v3` are Gated Repositories on Hugging Face. The application provides an integrated download verification tool (`download_models.py --hf-token <TOKEN>`) as well as a pre-packaged DSP acoustic evaluator to ensure the mobile app functions reliably out of the box.
