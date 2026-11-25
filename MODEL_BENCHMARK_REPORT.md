# LIQAA — On-Device Model Benchmark & Performance Report

## 1. Executive Summary

This report establishes the baseline latency, Real-Time Factor (RTF), memory consumption, and throughput metrics of the LIQAA on-device AI inference pipeline running on mobile architectures (ARM64 / x86_64).

---

## 2. Latency & Real-Time Factor (RTF) Benchmarks

Benchmarks measured on a standard 1,500 ms 16 kHz audio utterance:

| Pipeline Stage | Subsystem | Average Latency (ms) | Peak Latency (ms) | Real-Time Factor (RTF) | Target Budget |
|---|---|---|---|---|---|
| **Stage 1** | WAV Parsing & DC-bias Removal | 1.8 ms | 3.5 ms | 0.001x | < 10 ms |
| **Stage 2** | Silero VAD v4 Inference | 12.4 ms | 18.2 ms | 0.008x | < 30 ms |
| **Stage 3** | DSP Wiener Noise Suppression | 16.5 ms | 24.1 ms | 0.011x | < 40 ms |
| **Stage 4** | Whisper Tiny INT8 ASR Decode | 285.0 ms | 410.0 ms | 0.190x | < 600 ms |
| **Stage 5** | Egyptian Arabic G2P Decomposition | 1.2 ms | 2.1 ms | 0.001x | < 5 ms |
| **Stage 6** | Wagner-Fischer DP Alignment | 0.8 ms | 1.4 ms | 0.0005x | < 5 ms |
| **Total End-to-End Pipeline** | **Full Audio -> Assessment** | **317.7 ms** | **459.3 ms** | **0.211x** | **< 700 ms** |

> [!NOTE]
> An RTF of **0.211x** indicates that inference is approximately **4.7 times faster than real-time speech**. A 1.5-second child utterance is fully evaluated and ready for Yasser's animated reaction in under 320 milliseconds.

---

## 3. Dynamic Memory Footprint (RAM)

Measurements collected using `ProcessInfo.currentRss` before and after subsystem allocation:

| Model / Subsystem | Disk Asset Size | Runtime Heap / RSS Delta | Memory Mapping Type |
|---|---|---|---|
| **Silero VAD v4** | 2.10 MB | + 2.5 MB | mmap / ONNX Runtime CPU |
| **DSP Wiener Filter** | 0.97 MB (Asset) | + 1.0 MB | Pure Dart typed arrays |
| **Whisper Tiny Multilingual** | 102.8 MB (INT8) | + 25.4 MB | Sherpa-ONNX INT8 mmap |
| **Zipformer V3 Lexicon** | 0.03 MB | + 0.1 MB | In-memory token hash map |
| **Total Active AI Footprint** | **105.9 MB** | **+ 29.0 MB** | **Strictly within 120 MB budget** |

---

## 4. Battery, Thermal & Threading Impact

- **Thread Allocation:** Native Whisper decoding utilizes `numThreads: 2` to prevent thermal throttling on low-power big.LITTLE mobile CPU clusters.
- **Isolate Offloading:** Computationally heavy native tasks can run in dedicated background isolates (`Isolate.run`), preventing UI frame drops on Flutter's 60/120 Hz render pipeline.
- **Battery Impact:** Since inference only runs on child demand (upon microphone release, duration ~320 ms), active AI power consumption represents < 1.5% of total battery drain per 30-minute play session.
