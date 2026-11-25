# Audio Pipeline Root Cause & Remediation Report

## 1. Executive Summary
An end-to-end investigation of LIQAA's on-device audio capture, WAV container decoding, Voice Activity Detection (Silero VAD), noise suppression (GTCRN vs legacy RNNoise), and audio playback identified five distinct root causes explaining silent processed playback, VAD speech rejection, and downstream recognition failures. All five have been remediated and verified with automated tests (`flutter analyze` clean, `87/87` tests passing in `flutter test`).

---

## 2. Phase-by-Phase Root Causes & Fixes

### Phase 1: Audio Capture, WAV Header Corruption & Unified Preprocessing
- **Root Causes Found:**
  1. `lib/features/ai_lab/cubits/ai_lab_cubit.dart` (`stopRecordingAndAnalyze` and `runSttTest`) passed raw WAV file bytes directly to `preprocessor.pcm16ToFloat32(rawBytes)` without stripping or parsing the 44-byte RIFF/WAVE header, injecting ASCII header bytes (`"RIFF"`, `"WAVEfmt "`, `"data"`) as high-amplitude sample spikes into inference.
  2. `lib/core/ai/audio_preprocessor.dart` (`parseWavPcm`) scanned byte-by-byte from offset 12 looking for `"data"` rather than walking valid RIFF subchunks (`chunkId` + little-endian `chunkSize` with even-byte word alignment), risking false matches inside `JUNK`/`LIST`/`INFO` chunks, and ignored `fmt ` chunk fields (`audioFormat`, `channels`, `sampleRate`, `bitsPerSample`).
  3. `lib/core/ai/audio_recorder_service.dart` swallowed `stop()` / file-read errors by returning `Uint8List(0)` without verifying RIFF chunk integrity or waiting for file flush completion.
- **Implemented Remediation:**
  - Implemented `WavAudioMetadata` and strict chunk-walking `parseWavMetadata(Uint8List)` handling PCM (`audioFormat=1`), IEEE Float (`audioFormat=3`), and `WAVE_FORMAT_EXTENSIBLE` (`0xFFFE`), plus `InvalidAudioFormatException` on corrupt/truncated inputs.
  - Implemented `preprocessWav(Uint8List, targetSampleRate: 16000)` supporting 8/16/24/32-bit PCM & IEEE Float32 decoding, multi-channel downmixing to mono, anti-aliased linear resampling, RMS/peak/clipping calculation, and canonical 16kHz mono PCM16 WAV generation.
  - Updated `AudioRecorderService.stopRecording()` to wait for WAV file stabilization (`_waitForFinalizedWavFile`), validate the RIFF/WAVE header before returning bytes, lazily allocate `AudioRecorder`, and throw `AudioRecordingException` rather than silently returning empty buffers on failure.
  - Updated `ai_lab_cubit.dart` and `pronunciation_repository.dart` to share `preprocessor.preprocessWav(...)` across all diagnostic labs and the pronunciation game.

---

### Phase 2: Silero VAD Speech Rejection & Tail Truncation
- **Root Causes Found (Verified Live via Sherpa-ONNX 2.0.3 Native Calls):**
  1. Calling `_vad!.flush()` followed by requiring `if (detected && !_vad!.isEmpty())` in `lib/core/ai/silero_vad_engine.dart` failed because `VoiceActivityDetector.isDetected()` returns `false` after `flush()`, even when queued speech segments remain (`isEmpty() == false`). That caused total speech rejection on real speech prompts (`kora.wav`, `samaka.wav`).
  2. Passing an entire recording buffer in a single `_vad!.acceptWaveform(samples)` call caused Sherpa-ONNX `VoiceActivityDetector` to retain only the final trailing window (for a 7.1s recording `asc_0_16k.wav` of `113,729` samples, only `start=110592, len=3137` was returned, losing >97% of spoken audio).
  3. Only a single `front()`/`pop()` call was executed, ignoring multiple speech segments and lacking pre-roll/post-roll onset buffers (clipping initial stop bursts).
- **Implemented Remediation:**
  - `SileroVadEngine.analyze()` now feeds audio in exact `512`-sample frames (`windowSize: 512`), drains all queued segments (`while (!_vad!.isEmpty())`) both during frame streaming and after `_vad!.flush()`, and **never** gates post-flush draining on `isDetected()`.
  - Expanded each detected segment with `preRollMs = 150` and `postRollMs = 200` from the original normalized waveform, merged overlapping spans into structured `VadSegment` entries, and concatenated speech segments cleanly.
  - Lowered default `minSpeechDurationMs` from `120` to `80` so short Arabic syllables and isolated phonemes are preserved while stationary white noise and silence are rejected.

---

### Phase 3: Noise Suppression & Silent Audio Playback
- **Root Causes Found:**
  1. `lib/core/ai/pronunciation_repository.dart` (`analyzeAudioForLab`) assigned headerless raw PCM16 bytes (`preprocessor.float32ToPcm16(...)`) to `trimmedAudioBytes` and `denoisedAudioBytes`. Passing headerless PCM bytes to `audioplayers` `BytesSource(...)` failed playback/produced silence, while `mic_vad_view.dart` and `noise_reduction_view.dart` masked the issue with silent `?? audio.rawAudioBytes` fallbacks.
  2. `assets/ai_models/rnnoise/rnnoise.onnx` (`1,020,606` bytes) requires `main_input:0` shaped `[batch, 100, 42]` (42 BFCC features computed at 48kHz) and outputs `[batch, 100, 22]` band gains — it cannot process raw 16kHz waveforms. The previous `RnnoiseDenoiserEngine` ran only hand-written DSP Wiener subtraction (`isNeuralModel: false`).
  3. On clean-room speech (`rawSnr >= 22 dB`), running neural enhancement unconditionally attenuated brief voiceless stop aspiration bursts (observed on `correct_kora.wav`, shifting `/k/` toward `/p/`).
- **Implemented Remediation:**
  - Bundled MIT-licensed `assets/ai_models/gtcrn/gtcrn_simple.onnx` (`535,638` bytes, native 16kHz) and wired `RnnoiseDenoiserEngine` to `sherpa_onnx.OfflineSpeechDenoiser` (`DenoiserMode.neuralGtcrn`), with explicit `DenoiserMode.dspWienerFallback` and `DenoiserMode.bypass` options.
  - On failed neural initialization or inference (e.g., missing asset, NaN output, collapsed RMS), `DenoiseResult` now returns `hasValidAudio == false` with `errorMessage` populated — never silently substituting unmodified audio.
  - `analyzeAudioForLab()` wraps both `trimmedAudioBytes` and `denoisedAudioBytes` in valid 16kHz mono RIFF/WAVE headers via `preprocessor.float32ToWav(...)` (validated in tests by `parseWavMetadata`), and UI play buttons are disabled cleanly when processed audio is null.
  - `evaluateAudio()` applies automatic GTCRN suppression when `rawSnr < 22.0 dB` (or when `overrideDenoise == true`) and normalizes peak amplitude only on genuinely quiet inputs (`rawRms < 0.05`).
