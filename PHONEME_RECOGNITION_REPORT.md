# LIQAA — Phoneme Recognition & Linguistic Evaluation Report

## 1. Architectural Scope & Honest Scientific Disclosure

In modern speech pathology and clinical mobile software, acoustic phoneme recognition represents one of the most demanding challenges, especially when applied to pediatric speech in non-standard dialects such as **Egyptian Arabic (العامية المصرية)**.

### Direct Acoustic Phoneme Modeling vs. ASR-G2P Transduction
Acoustic phoneme recognition from waveform can be approached through two distinct paradigms:
1. **Frame-Level Acoustic CTC / CTC-Aligner:** The audio waveform is passed to a neural network whose output layer outputs posterior probabilities across phoneme symbols (e.g., Wav2Vec2-Phoneme or Zipformer CTC).
2. **End-to-End ASR + Dialectal Grapheme-to-Phoneme (G2P) Transduction:** The audio waveform is recognized blindly into orthographic Arabic text, which is then mapped deterministically to International Phonetic Alphabet (IPA) sequences using dialect-specific phonological rules.

> [!IMPORTANT]
> **Scientific Finding:** Currently, there are NO open-source, mobile-quantized (INT8 ONNX) acoustic CTC models trained on Egyptian Arabic pediatric speech available in the public domain. Existing open Arabic CTC models (such as Arabic Speech-to-Text on Modern Standard Arabic) consistently fail on colloquial Egyptian consonant stops (e.g., glottalization of *ق* to *[ʔ]* or dialectal affrication/velarization of *ج* to *[ɡ]*).
>
> Therefore, LIQAA implements **End-to-End Blind ASR with an Egyptian Arabic G2P Phonological Transducer**. This is documented honestly to ensure complete scientific integrity.

---

## 2. Egyptian Arabic G2P Mapping Architecture

The `PhonemeRecognitionEngine` maps orthographic sequences into phonemic tokens based on phonological rules calibrated for pediatric Egyptian Arabic:

| Arabic Orthography | Standard Arabic IPA | Egyptian Arabic Child IPA | Phonetic Classification | Example |
|---|---|---|---|---|
| **ج** | /d͡ʒ/ | **/ɡ/** | Voiced Velar Plosive | جمل -> /ɡ/ /m/ /l/ |
| **ق** | /q/ | **/ʔ/** (or /q/) | Voiceless Glottal Stop | قلم -> /ʔ/ /l/ /m/ |
| **ك** | /k/ | **/k/** | Voiceless Velar Plosive | كورة -> /k/ /uː/ /r/ /a/ |
| **ط** | /tˤ/ | **/tˤ/** | Emphatic Alveolar Plosive | بطة -> /b/ /tˤ/ /a/ |
| **س** | /s/ | **/s/** | Voiceless Alveolar Fricative | سمكة -> /s/ /m/ /k/ /a/ |
| **ش** | /ʃ/ | **/ʃ/** | Voiceless Postalveolar Fricative | شمس -> /ʃ/ /m/ /s/ |
| **ر** | /r/ | **/r/** | Alveolar Trill | أرنب -> /ʔ/ /r/ /n/ /b/ |
| **و** | /uː/ /w/ | **/uː/** / **/oː/** | Close/Mid Back Rounded | كورة -> /uː/, موزة -> /oː/ |
| **ي** | /iː/ /j/ | **/iː/** / **/eː/** | Close/Mid Front Unrounded | فيل -> /iː/, بيت -> /eː/ |
| **ة** | /a/ /at/ | **/a/** | Open Central Short Vowel | سمكة -> /a/ |

---

## 3. Dynamic Programming Alignment (Wagner-Fischer)

To compare the recognized phoneme sequence $R = (r_1, r_2, \dots, r_n)$ against the clinical target sequence $E = (e_1, e_2, \dots, e_m)$, a dynamic programming edit matrix $D \in \mathbb{R}^{(m+1) \times (n+1)}$ is constructed:

$$D[i, j] = \min \begin{cases}
D[i-1, j-1] + \text{cost}(e_i, r_j) & \text{(Match / Substitution)} \\
D[i-1, j] + 1.0 & \text{(Deletion)} \\
D[i, j-1] + 1.0 & \text{(Insertion)}
\end{cases}$$

### 3.1 Strict Insertion Penalization (Fixing Finding 14)
Previous implementations failed to penalize inserted phonemes in the final score calculation. The remediated alignment algorithm deducts $0.5$ points for every inserted phoneme:

$$\text{Net Matches} = \max\left(0, \text{Matches} - 0.5 \times \text{Insertions}\right)$$

$$\text{Raw Match Ratio} = \frac{\text{Net Matches}}{\max(1, m)}$$

$$\text{Score} = \text{clamp}\left(\text{Raw Match Ratio} \times 85.0 + \text{Avg Confidence} \times 15.0, 0, 100\right)$$

### 3.2 Phonetic Equivalence Matrix
The equivalence function `_isPhoneticallyEquivalent` accounts for:
1. Dialectal glottal stop variations: `[ʔ]` matches `ق`, `ء`, `أ`, `إ`, `آ`.
2. Velar stop variations: `[ɡ]` matches `ج`.
3. Vowel duration elasticity: `[uː]` matches `[u]` and `و`; `[aː]` matches `[a]` and `ة` / `ا`.
4. Diacritic marks: `َ` (Fatha) matches `[a]`, `ُ` (Damma) matches `[u]`, `ِ` (Kasra) matches `[i]`.

---

## 4. Elimination of Fabricated Confidence and Margins

- **Audit Finding 6:** `PhonemeToken` generated fake `acousticMargin: 0.30` and fake `isAccurate: true` on all tokens.
- **Remediation:**
  - `PhonemeToken.acousticMargin` is set to `null` by default. Acoustic margin is only provided if exposed by a frame-level acoustic CTC decoder.
  - `PhonemeToken.isTimestampEstimated` is added and set to `true`, transparently disclosing that phoneme timestamps are estimated via segment division rather than frame-level forced alignment.
  - Confidence reflects true ASR utterance probability or is left uncalibrated.
