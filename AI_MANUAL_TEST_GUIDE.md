# LIQAA — AI Manual Testing and Verification Guide

## 1. Overview

This manual testing guide enables developers, QA testers, and speech pathologists to comprehensively test each component of the LIQAA on-device speech AI subsystem.

---

## 2. Testing Environment Checklist

- **Device:** Android physical device or emulator (API 26+), iOS device (iOS 13+), or Windows Desktop runner.
- **Permissions:** Microphone permission granted (`RECORD_AUDIO`).
- **Network:** Testing should be performed **offline (Airplane mode)** to verify zero cloud dependency.

---

## 3. Step-by-Step Test Scenarios in Yasser AI Lab

Access Yasser AI Lab from the Developer Gateway:
Path: App Launch $\rightarrow$ Splash $\rightarrow$ Onboarding $\rightarrow$ Role Selection Screen $\rightarrow$ Tap **"مختبر ياسر للذكاء الاصطناعي (AI Lab)"** or navigate to route `/ai-lab`.

### Scenario 1: Model Manager Screen (`/ai-lab/models`)
1. Open Screen 1: Model Manager.
2. Verify all models are listed:
   - Silero VAD (2.1 MB)
   - RNNoise (0.97 MB)
   - Zipformer Arabic V3 / V2 (65 MB)
   - Nabra 82M ASR (79 MB)
3. Check file status: Status badges should show "Ready" or "Available".
4. Tap **"Verify Integrity"**: SHA256 checksums should match the manifest.
5. Tap **"Load into Memory"** and **"Unload from Memory"**: Monitor RAM gauge and verify heap release.

### Scenario 2: Mic & Silero VAD Test (`/ai-lab/vad`)
1. Open Screen 2: Mic & VAD.
2. Tap the Microphone button and speak an Arabic word (e.g., "كورة").
3. Observe the live real-time waveform: amplitude should respond dynamically.
4. Stop speaking and pause for 1 second.
5. Verify the VAD status switches from "Speech Active (صوت)" to "Silence (صمت)".
6. Inspect the detected speech boundaries: Start timestamp (ms), End timestamp (ms), and Duration (ms).
7. Tap **"Play Raw Audio"** vs. **"Play Trimmed Speech"** to verify silence trimming.

### Scenario 3: Noise Reduction Test (`/ai-lab/noise`)
1. Open Screen 3: Noise Reduction.
2. Record an audio clip with background fan or desk noise.
3. Toggle the **"تفعيل عزل الضوضاء (RNNoise)"** switch.
4. Listen to **Raw Audio** vs. **Denoised Audio** using the dual audio players.
5. Verify estimated SNR improvement (e.g., $+4.2\text{ dB}$).
6. Inspect the spectral envelope overlay showing noise floor suppression.

### Scenario 4: Phoneme Recognition Test (`/ai-lab/phonemes`)
1. Open Screen 4: Phoneme Recognition.
2. Select target word **كورة** from the dropdown.
3. Intentionally pronounce **"تورة"** (simulating pediatric fronting error).
4. Tap **"تحليل الفونيمات (Analyze Phonemes)"**.
5. Verify output:
   - Expected Phonemes: `[k, uː, r, a]`
   - Recognized Phonemes: `[t, uː, r, a]`
   - Error Flag: Substitution detected on initial consonant ($[k] \rightarrow [t]$).
   - Alignment table displays red highlight on the substituted token.
6. Inspect raw acoustic token log: frame numbers, token IDs, and probability scores.

### Scenario 5: Speech-to-Text Test (`/ai-lab/stt`)
1. Open Screen 5: Speech-to-Text.
2. Record a complete Egyptian phrase (e.g., "أنا بلعب بالكورة").
3. Tap **"Transcribe"**.
4. Verify transcription text, latency (ms), and Real-Time Factor (RTF $< 0.20$).

### Scenario 6: Model Comparison (`/ai-lab/compare`)
1. Open Screen 6: Model Comparison.
2. Review side-by-side benchmark tables for Zipformer V2, V3, and Nabra.
3. Select an audio sample from the test assets (`correct_kora.wav` or `error_tora.wav`).
4. Tap **"Run Comparative Inference"** and verify metric alignment.

### Scenario 7: Full Pipeline & Export (`/ai-lab/pipeline`)
1. Open Screen 7: Full Pipeline.
2. Tap **"Run Full Pipeline"** to execute Mic $\rightarrow$ VAD $\rightarrow$ Denoiser $\rightarrow$ Phoneme CTC $\rightarrow$ Evaluator.
3. Verify step-by-step timeline shows latency per stage.
4. Tap **"Export Report (JSON / CSV)"** to share or inspect diagnostic data.

---

## 4. Child Game Flow: "انطق مع ياسر" (`/game`)

1. Navigate to **انطق مع ياسر (Speak With Yasser)**.
2. Select the word card **كورة**.
3. Yasser appears in a cheerful waiting pose.
4. Tap the large microphone button.
5. **Test Case A (Correct Pronunciation):**
   - Say: "كورة".
   - Expected: Score $\ge 90\%$, 3 golden stars, celebratory confetti, Yasser celebration pose (`celebrating.png`), voice feedback: "برافو يا بطل! نطقت كورة ممتاز!".
6. **Test Case B (Child Fronting Error):**
   - Say: "تورة".
   - Expected: Score $\approx 65\%$, Yasser thinking pose (`thinking.png`), highlighted letter **ك**, voice/text guidance: "شاطر جداً! بس بدّلنا صوت الـ ك بصوت الـ ت.. يلا نطلع صوت الكاف من ورا: كـ كورة!".
7. Verify tap on **"اسمع ياسر"** replays clean model pronunciation.
