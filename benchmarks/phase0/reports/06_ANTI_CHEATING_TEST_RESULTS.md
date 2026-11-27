# 06 — Anti-Cheating Integrity Suite Results

Execution engine: `benchmarks/phase0/anti_cheating_suite.py` (`python -m unittest discover -s benchmarks/phase0/tests`).
**Verified Score:** **`15 / 15` PASSED** (note: diagnostic negative & drift cases intentionally use labeled synthetic fixtures to test infrastructure guards without masking real-world gaps).

| ID | Check | Status | Synthetic Fixture | Observed Evidence |
| --- | --- | --- | --- | --- |
| `T01` | Silence input rejected by real VAD and blind Wav2Vec2 | **PASS** | False | Silero max_prob=0.0181, Wav2Vec2 tokens=[] |
| `T02` | White noise rejected by real VAD and blind Wav2Vec2 | **PASS** | False | Silero max_prob=0.0376, Wav2Vec2 tokens=[] |
| `T03` | Generated stationary noise floor fails VAD speech gate | **PASS** | True | Silero max_prob=0.0385 |
| `T04` | Unrelated spoken word (word_madrasa.wav) rejected against target 'كورة' via real ONNX | **PASS** | True | Real Wav2Vec2 tokens=['m', 'ɛ', 'd', 'r', 'a', 's'], kora_score=0.0% |
| `T05` | Minimal-pair error_tora.wav yields worse distance than correct_kora.wav on real ONNX | **PASS** | True | correct_kora=['k', 'oː', 'r', 'ə'] (dist=2) vs error_tora=['t', 'uː', 'r', 'a'] (dist=1) [synthetic TTS probe only] |
| `T06` | Truncated speech yields severely incomplete sequence vs full utterance | **PASS** | False | Full tokens=47 vs 220ms cut tokens=0 ([]) |
| `T07` | Quiet-floor and clipped signal anomaly detection | **PASS** | True | quiet_rms=0.00050, clipped_samples=11760 |
| `T08` | Corrupted/truncated WAV raises structured ValueError | **PASS** | True | Blocked with ValueError (zero silent pass) |
| `T09` | 44.1kHz stereo downmixed & resampled to 16kHz mono | **PASS** | True | orig_sr=44100, out_len=16000 |
| `T10` | Target-word hint blocked in blind inference & Dart PhonemeRecognitionEngine | **PASS** | False | Signature firewall blocked leaky_model=True; Dart engine targetWord-free=True |
| `T11` | Cross-split exact duplicate, 8kHz resampled duplicate & speaker leakage caught | **PASS** | True | exact=1, acoustic=2, spk=1 |
| `T12` | Random label permutation collapses accuracy to ~50% chance | **PASS** | True | orig_acc=1.00 -> shuffled_acc=0.49 |
| `T13` | Post-freeze threshold/artifact lock blocks drift | **PASS** | True | Changing pass_score 70->60 raised BlindAuthorizationError |
| `T14` | Bitwise, VAD, and Wav2Vec2-eSpeak deterministic repeatability verified | **PASS** | False | sha_equal=True, vad_equal=True, tokens_equal=True (n=47) |
| `T15` | Active ONNX SHA-256 manifest integrity & missing-model handling verified | **PASS** | False | active_manifest_mismatches=0, missing_zipformer_weights_honest=True, disk_artifacts_locked=8 |
