# PRONUNCIATION EVALUATION & ANTI-CHEATING REPORT

**Evaluated Modules:** [pronunciation_repository.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/pronunciation_repository.dart), [pronunciation_evaluator.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/pronunciation_evaluator.dart), [egyptian_arabic_dictionary.json](file:///e:/Flutter%20Projects/liqaa_app/assets/pronunciation/egyptian_arabic_dictionary.json).

---

## 1. End-to-End 100-Sample Evaluation Outcomes (Post-Fix vs. Baseline)

| Benchmark Category | `n` | Baseline Pass (`Mean`) | **Post-Fix Pass (`Mean`)** | Dominant Error Types (Post-Fix) | Clinical Interpretation |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `correct_pediatric` | 20 | `0/20 (0.0%)` (`30.2`) | **`1/20 (5.0%)` (`35.5`)** | `substitution: 9`, `unrelatedWord: 8`, `uncertain: 1`, `correct: 1`, `noSpeech: 1` | **Wilson 95% CI `[0.89%, 23.61%]`** — `S011 كورة` passed at `94.4%` (`[k ʉ r aː]`), but `19/20` false-rejected |
| `genuine_pediatric_errors` | 20 | `0/20` (`24.7`) | **`0/20` (`24.0`)** | `unrelatedWord: 13`, `substitution: 5`, `deletion: 1`, `uncertain: 1` | **`100.0%` (`[83.89%, 100%]`) error rejection** |
| `unrelated_word_pediatric` | 10 | `0/10` (`20.3`) | **`0/10` (`17.0`)** | `unrelatedWord: 9`, `deletion: 1` | **`100.0%` (`[72.25%, 100%]`) unrelated rejection** |
| `quiet_weak_pediatric` | 10 | `0/10` (`28.0`) | `0/10` (`32.7`) | `unrelatedWord: 5`, `substitution: 4`, `noSpeech: 1` | Mean score lifted `+4.7 pts` after VAD-before-normalize fix |
| `noisy_pediatric` | 10 | `0/10` (`29.7`) | `0/10` (`27.4`) | `unrelatedWord: 6`, `deletion: 2`, `substitution: 1`, `noSpeech: 1` | `S069 المدرسة` scored `67.9%` (`[m a d ɾ a s a]`) — dropped initial `الـ` `[aː l]` |
| `adult_arabic_speech` | 10 | `0/10` (`23.8`) | `0/10` (`26.1`) | `unrelatedWord: 7`, `substitution: 3` | Expected fail (`target_word` vs multi-sentence passages / missing sentence templates) |
| `silence_near_silence` | 5 | `0/5` (`0.0`) | **`0/5` (`0.0`)** | `noSpeech: 5` | **`100.0%` clean silence rejection** |
| `environmental_noise` | 5 | `0/5` (`0.0`) | **`0/5` (`0.0`)** | `noSpeech: 5` | **`100.0%` MUSAN non-speech rejection** |
| `isolated_consonants_syllables` | 5 | `1/5` (`43.8`) | **`1/5` (`43.8`)** | `correct: 1`, `substitution: 2`, `deletion: 1`, `uncertain: 1` | `S091 كاف` passed at **`91.0%`**; `S095 ألف` scored `64.5%` |
| `difficult_edge_cases` | 5 | `0/5` (`57.9`) | `0/5` (`58.0`) | `substitution: 4`, `deletion: 1` | `S098 باذنجان` `69.8%`, `S099 ثلاجة` `62.2%`, `S096 بطة` `60.9%` |

---

## 2. Controlled Synthetic TTS Minimal Pairs (Separate Diagnostic Fixtures)

On clean Edge Neural TTS minimal pairs (`assets/audio_samples/`), acoustic separation is sharp and reliable:

| Fixture | Target Word | Recognized IPA | Passed | Score | Error Type | Clinical Expectation |
| :--- | :--- | :--- | :---: | :---: | :--- | :--- |
| `SYNTH_correct_kora` | `كورة` | `[k, oː, r, ə]` | **`true`** | **`91.8%`** | `correct` | Exact `/k/` & syllable match -> PASS |
| `SYNTH_error_tora` | `كورة` | `[t, uː, r, a]` | **`false`** | `65.0%` | `substitution` | Velar fronting `/k -> t/` detected -> REJECT |
| `SYNTH_correct_arnab` | `أرنب` | `[a, r, n, a, b, m, i]` | **`true`** | **`80.6%`** | `correct` | Clean `/r/` -> PASS |
| `SYNTH_error_anlab` | `أرنب` | `[ʔ, a, l, l, a, b]` | **`false`** | `59.8%` | `substitution` | Lateralization `/r -> l/` detected -> REJECT |
| `SYNTH_word_madrasa` | `كورة` | `[m, ɛ, d, r, a, s]` | **`false`** | `39.3%` | `substitution` | Unrelated word rejected -> REJECT |

---

## 3. Scoring Bottlenecks on Near-Pass Real Child Utterances

Auditing real child recordings that came close to passing reveals why `19/20` correct pediatric clips were rejected:
1. **`S014 فراشة` (`78.1%`, `substitution`):** Real child emitted `[f ɑ a ʃ a]` (only `/r/` weak/elided vs `[f r aː ʃ a]`, missed `80.0%` threshold by `1.9 pts`).
2. **`S005 أمي` (`68.0%`, `substitution`) & `S013 أرنب` (`68.0%`, `substitution`):** Real children drop or soften glottal onset `/ʔ/` (`[o m i]`, `[ɑ i n aː b]`). `PronunciationEvaluator` marks initial `ʔ -> <DEL>` as an essential mismatch when comparing against whole-word `[ʔ, r, n, b]`.
3. **`S069 المدرسة` (`67.9%`, `deletion`) & `S007 الأرض` (`61.7%`):** Dictionary entries encode full MSA definite article `[aː l ...]` (`المدرسة`), whereas children spoken naturally frequently drop or coarticulate the initial `[a]`/`[l]` (`[m a d ɾ a s a]`), triggering strict `deletions > 0` failure even when all root consonants match!
4. **High Strictness Thresholds (`score >= 80.0 && deletions == 0`):** Appropriate for adult/TTS studio audio, overly punitive for 2–8 year old speech therapy games where target-phoneme accuracy matters more than secondary weak vowel/prefix retention.

---

## 4. Anti-Cheating & Missing-Model Integrity Verification

From [anti_cheating_results.json](file:///e:/Flutter%20Projects/liqaa_app/benchmarks/results/anti_cheating_results.json):
- **Target-Word Leakage Test:** Evaluating the exact same audio `assets/audio_samples/correct_kora.wav` across 5 different targets produced an **identical timestamped acoustic IPA signature** (`k@143-163|uː@225-245|ɹ@368-388|ə@408-429`) across all 5 runs (`ipa_invariant_across_all_targets: true`):
  - `كورة`: **`91.8%` (`correct`, PASS)**
  - `مدرسة`: `39.4%` (`substitution`, REJECT)
  - `سمكة`: `25.9%` (`unrelatedWord`, REJECT)
  - `أرنب`: `24.2%` (`unrelatedWord`, REJECT)
  - `باب`: `6.8%` (`unrelatedWord`, REJECT)
- **Failure Honesty Test:** Removing the Wav2Vec2 ONNX asset path returns structured failure **`errorType: modelInitFailed`**, **`pipelineStageFailed: PhonemeRecognition`** (`0` fake positive fallback).
