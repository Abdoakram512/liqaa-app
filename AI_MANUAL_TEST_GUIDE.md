# LIQAA — Manual Verification and Testing Guide

This guide describes how quality engineers and developers can manually test and verify the on-device AI system on Android, iOS, or emulator devices.

---

## 1. Quick Verification via Developer AI Lab

The app includes a dedicated developer laboratory with 9 diagnostic screens:

1. Launch the app and navigate to **مختبر الذكاء الاصطناعي (AI Lab)** via the psychology brain icon in the game header, or route to `/ai-lab`.
2. Inspect the 9 diagnostic screens:
   - **Lab 1: Model Manager (`/ai-lab/models`)**
     - Verify all models are marked "ready": Silero VAD (2.1 MB), RNNoise (0.97 MB), Whisper Tiny (98.8 MB).
     - Tap "تشغيل اختبار السلامة (Smoke Test)" on each model and verify green checkmarks.
   - **Lab 2: Mic & Silero VAD (`/ai-lab/vad`)**
     - Tap the record button. Speak a word, then remain silent for 1 second.
     - Verify that the blue/green wave shows speech detection, start timestamp, and end timestamp.
     - Observe silence trimming.
   - **Lab 3: Noise Reduction (`/ai-lab/noise`)**
     - Record in a room with background noise.
     - Toggle noise suppression on/off and inspect the SNR improvement metric in dB.
   - **Lab 4: Phoneme Recognition (`/ai-lab/phonemes`)**
     - Test phoneme segmentation with real spoken Egyptian Arabic.
   - **Lab 5: Speech-to-Text (`/ai-lab/stt`)**
     - Record unguided Arabic sentences and verify real-time speech transcription with RTF metrics.
   - **Lab 6: Model Comparison (`/ai-lab/compare`)**
     - Inspect comparative latency, RAM, and licensing metrics.
   - **Lab 7: Full Pipeline & Export (`/ai-lab/pipeline`)**
     - Run complete end-to-end recording and export diagnostic JSON.
   - **Lab 8: Clinical Benchmark (`/ai-lab/benchmark`)**
     - Tap on any of the 8 clinical test scenarios (e.g., `تورة`, `ثمكة`, `أنلب`, `صمت`).
     - Observe the real Wagner-Fischer DP matrix and clinical diagnosis.
   - **Lab 9: Free Speech & Blind Phoneme Recognition (`/ai-lab/blind`)**
     - Record arbitrary words or sentences without selecting any card.
     - Verify zero target leakage: the system transcribes and extracts phonemes blindly from live audio!

---

## 2. Pronunciation Game User Journey Verification

1. Navigate to the game screen (**انطق مع ياسر**).
2. **Negative Test 1 (Silence):**
   - Press the microphone button and remain completely silent.
   - Stop recording.
   - **Expected Result:** Score is 0.0%, 0 stars awarded, `wordsMasteredCount` does NOT increment. Yasser avatar shows `thinking` pose and prompts: "مش سامع صوتك كويس يا بطل! علّي صوتك ويلا نجرب تاني."
3. **Negative Test 2 (Substitution Error - Fronting):**
   - Select the word card `كورة` (Target: ك).
   - Press the mic and say clearly: **"تورة"**.
   - **Expected Result:** Score is capped at $\le 65\%$, stars awarded = 1 (retry), not passed. Yasser says: "شاطر جداً! بس بدّلنا صوت الـ ك بالـ ت.. يلا نطلع الكاف: كـ كورة!".
4. **Positive Test (Correct Pronunciation):**
   - Select card `كورة`.
   - Press the mic and say clearly: **"كورة"**.
   - **Expected Result:** Score $\ge 90\%$, 3 stars awarded, word mastered count increments. Confetti triggers and Yasser avatar celebrates!
