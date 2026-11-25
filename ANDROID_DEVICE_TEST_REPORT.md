# Android Build & Device Test Report

## 1. Device Connectivity Status (Honesty Disclosure)
- Command executed: `adb devices`
- Output observed: `List of devices attached` (empty — **zero physical Android devices or emulators connected** during this verification session).
- **Consequently:** Live hardware microphone capture, Android speaker playback, and runtime execution on a physical Android phone were **NOT executed** and remain pending device attachment.

---

## 2. Release Android APK Build Verification
- Command executed: `flutter build apk --release`
- Result: **Succeeded cleanly** (`exit code 0` in `807.1s`).
- Output artifact: `build/app/outputs/flutter-apk/app-release.apk` (`455.8 MB`).
- Android manifest & Gradle updates applied for large on-device neural inference bundles:
  - Added `android:largeHeap="true"` in `android/app/src/main/AndroidManifest.xml`.
  - Added `androidResources { noCompress += listOf("onnx", "wav", "riv") }` in `android/app/build.gradle.kts`.

### Verified APK Contents (`zipfile` inspection)
- **Native Shared Libraries (3 ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64`):**
  - `libonnxruntime.so` (`arm64-v8a`: `22,249,552` bytes)
  - `libsherpa-onnx-c-api.so` (`arm64-v8a`: `5,236,536` bytes)
  - `libsherpa-onnx-cxx-api.so` (`arm64-v8a`: `446,944` bytes)
  - `librive_native.so` (`arm64-v8a`: `7,675,336` bytes)
- **Bundled Uncompressed Neural Model Assets (`flutter_assets/assets/ai_models/`):**
  - `gtcrn/gtcrn_simple.onnx`: `535,638` bytes (`compress_size == 535,638`)
  - `silero/silero_vad.onnx`: `2,204,103` bytes (`compress_size == 2,204,103`)
  - `wav2vec2_espeak/model_q4f16.onnx`: `196,911,845` bytes (`compress_size == 196,911,845`)
  - `wav2vec2_espeak/vocab.json`: `4,637` bytes
  - `whisper_tiny/tiny-encoder.int8.onnx`: `12,937,772` bytes (`compress_size == 12,937,772`)
  - `whisper_tiny/tiny-decoder.int8.onnx`: `89,855,401` bytes (`compress_size == 89,855,401`)

---

## 3. Host Verification Executed (`flutter analyze` & `flutter test`)
- `flutter analyze`: `No issues found! (ran in 15.5s)`
- `flutter test`: `87` tests passed, `0` failed, including native Windows x64 execution of all 4 ONNX models (`Silero VAD`, `GTCRN`, `Wav2Vec2-eSpeak Q4F16`, `Whisper Tiny INT8`).

---

## 4. Next Steps on Physical Android Device
Once a physical Android device with USB debugging enabled is connected (`adb devices`):
```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```
Verify manually across Lab 1 (Model Manager), Lab 2 (Mic & Silero VAD playback), Lab 3 (GTCRN Neural Denoiser Original vs Processed playback), Lab 4/9 (Blind Wav2Vec2-eSpeak IPA), Lab 7 (Pipeline Inspector), and the Pronunciation Game with real spoken Arabic utterances (`كورة`, `تورة`, `سمكة`, `أرنب`, `أنلب`), quiet whispers, background noise, and silence.
