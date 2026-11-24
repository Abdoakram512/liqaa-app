# LIQAA — AI Dependencies and Runtime Compatibility Report

## 1. Overview

This document reports all runtime dependencies, platform integrations, binary packages, and permission profiles utilized by the LIQAA on-device AI speech processing pipeline.

---

## 2. Direct AI & Audio Dependencies

| Dependency | Resolved Version | Role & Justification | Platform Support | Size Impact |
| :--- | :--- | :--- | :--- | :--- |
| `record` | `^6.2.1` | Cross-platform, low-latency audio recording with direct PCM/WAV 16kHz stream extraction. | Android, iOS, Windows, macOS, Linux, Web | ~250 KB |
| `sherpa_onnx` | `^2.0.3` | Native ONNX runtime wrapper for streaming Zipformer, Conformer, CTC decoders, and Silero VAD. | Android (ARM64, ARMv7, x86_64), iOS (ARM64), Windows, macOS, Linux | Native libs bundled per ABI |
| `audioplayers` | `^6.7.1` | Low-latency audio playback for child pronunciation verification and celebratory sound effects. | Android, iOS, Windows, macOS, Linux, Web | ~400 KB |
| `permission_handler` | `^13.0.2` | Runtime permission orchestration for Android `RECORD_AUDIO` and iOS `NSMicrophoneUsageDescription`. | Android, iOS, Windows | ~180 KB |
| `path_provider` | `^2.1.6` | Filesystem resolution for locating local cached AI models, dictionary manifests, and WAV buffers. | Android, iOS, Windows, macOS, Linux | ~120 KB |
| `share_plus` | `^12.0.2` | Diagnostic export of AI benchmark and test results in JSON/CSV formats from Yasser AI Lab. | Android, iOS, Windows, macOS, Linux, Web | ~210 KB |

---

## 3. Platform Configuration & Permission Profiles

### 3.1 Android Integration
File: `android/app/src/main/AndroidManifest.xml`
```xml
<!-- Audio Recording Permissions -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

<!-- Model Acquisition from Free Open Repositories -->
<uses-permission android:name="android.permission.INTERNET" />
```
- **Android Min SDK:** 21 (Android 5.0 Lollipop)
- **Target SDK:** 34+ (Android 14)
- **NDK Architectures:** `arm64-v8a`, `armeabi-v7a`, `x86_64`

### 3.2 iOS Integration
File: `ios/Runner/Info.plist`
```xml
<!-- Microphone Usage Permission Description in Arabic -->
<key>NSMicrophoneUsageDescription</key>
<string>تطبيق لقاء يحتاج إلى إذن استخدام الميكروفون لتمكين الطفل من التحدث وتدريب النطق مع ياسر.</string>
```
- **iOS Minimum Deployment Target:** 12.0+
- **Architectures:** `arm64`

---

## 4. Disk & Memory Optimization Measures

1. **PUB_CACHE & Temporary Drive Redirect:**
   - On Windows development environments where system drive `C:` has limited capacity, `PUB_CACHE` and `TEMP` were reconfigured to drive `E:\` (`E:\pub_cache`, `E:\temp`), preventing disk exhaustion during native archive extraction.
2. **On-Demand Engine Loading:**
   - The AI engines (`SileroVadEngine`, `RnnoiseDenoiserEngine`, `PhonemeRecognitionEngine`) support lazy instantiation and explicit `dispose()` / `unloadFromRam()` methods, releasing neural network buffers when the user exits the training session.
3. **In-Memory Float32List Streaming:**
   - Raw audio samples are passed as zero-copy contiguous `Float32List` buffers between the recorder, preprocessor, and ONNX tensors, eliminating redundant disk I/O bottlenecks.
