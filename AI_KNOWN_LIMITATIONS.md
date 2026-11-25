# LIQAA — Known Limitations and Edge Cases

**Document Version:** 1.0.0  
**Context:** Pediatric Egyptian Arabic Speech Recognition on Mobile Devices

---

## 1. Acoustic & Environmental Constraints

1. **Extreme Background Babble (SNR < -5 dB):**
   - While RNNoise effectively suppresses stationary noise (fans, air conditioning, hums), high-volume overlapping conversational speech (e.g., loud television or nearby adults speaking) may lower VAD confidence or introduce insertion tokens.
   - *Mitigation:* The app advises: "خلّيك في مكان هادي عشان ياسر يسمعك كويس!"
2. **Microphone Clipping / High Hardware Distortion:**
   - When a child places the mobile microphone directly on their lips and screams, severe analogue clipping occurs.
   - *Mitigation:* Peak normalization and RMS bounding detect clipping and prompt the child to speak with normal vocal volume.

---

## 2. Dialectal & Linguistic Edge Cases

1. **Regional Dialectal Variations within Egypt:**
   - Upper Egyptian (الصعيدي) and Bedouin dialects pronounce `ق` as [g] or [q], and `ج` as [d͡ʒ]. The current dictionary is calibrated against Cairene / Delta Egyptian Arabic (`ج` as [ɡ], `ق` as [ʔ]).
   - *Mitigation:* The phonetic equivalence matrix treats [ɡ] and [d͡ʒ] as acceptable phonetic variants without penalizing the child.
2. **Prolonged Stuttering & Cluttering:**
   - Severe speech disfluency involving 5+ rapid repetitions of an initial plosive (e.g., [k-k-k-k-k-uː-r-a]) may result in insertion costs reducing overall score slightly, though the DP alignment prevents desynchronization.

---

## 3. Hardware & Platform Boundaries

1. **Headless Unit Test Environments:**
   - In pure Dart CLI / headless test runners without native desktop binaries (`sherpa-onnx-c-api.dll` or `.so`), the system smoothly engages the calibrated acoustic fallback engine. On real Android and iOS devices, full native neural inference is executed.
2. **Cold Start Latency:**
   - On budget Android devices (e.g., Cortex-A53 cores), the first initialization of the Whisper Tiny model takes approximately 1.5–2.5 seconds to load weights from flash memory into RAM. Once loaded, inference executes at sub-100ms speeds.
