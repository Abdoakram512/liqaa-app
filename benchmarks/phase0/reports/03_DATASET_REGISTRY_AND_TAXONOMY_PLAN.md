# 03 — Dataset Registry & Taxonomy Plan

Machine-readable source: `benchmarks/phase0/DATASET_REGISTRY.json` (`10` dataset specifications).

## Mutually Exclusive Taxonomy Rules
Every sample holds ONE primary category from `pediatric_correct, pediatric_mispronounced, pediatric_noise_or_weak, adult_arabic_speech, non_speech_noise_and_silence, controlled_synthetic, unassigned_unknown`:
1. Zero duplicate assignment across categories; noise/SNR/speed/TTS flags live in secondary metadata (`is_synthetic`, `snr_bucket`, `parent_source_id`).
2. `controlled_synthetic` samples are strictly **0%** inside Stage B Blind Holdout.
3. No relabeling or fabrication of missing phonetic alignments (`ground_truth_reliability` preserves true granularity).

## Verified Datasets
| `dataset_id` | Status | Dialect | Age | License | Commercial | Local Phase 0 Clips |
| --- | --- | --- | --- | --- | --- | --- |
| `asmdd` | `PUBLIC_VERIFIED_LOCAL_SUBSET` | Egyptian Arabic | Pediatric (reported ~2-8 years) | CC0 1.0 | True | 41 |
| `abjad_kids` | `PUBLIC_HF_VERIFIED_LOCAL_SUBSET` | Multi-Dialect / Modern Standard Arabic | Pediatric (reported ~3-12 years) | MIT | True | 39 |
| `arayoungvoices` | `LITERATURE_VERIFIED_PUBLIC_REPO_UNVERIFIED` | Modern Standard Arabic + L1/L2 young speakers | Child & Adolescent (reported 7-18 years) | UNKNOWN (literature-reported CC BY-NC-SA 4.0 / academic release — requires direct license inspection prior to use) | False | 0 |
| `arabic_egy_cleaned` | `PUBLIC_HF_VERIFIED_NOT_DOWNLOADED` | Egyptian Arabic | Adult (predominantly adult conversational/media) | UNKNOWN (HF card license field null — DO NOT assume commercial clearance without upstream verification) | False | 0 |
| `egyspeak` | `PUBLIC_HF_VERIFIED_NOT_DOWNLOADED` | Egyptian Arabic | Adult | CC-BY-4.0 | True | 0 |
| `arabic_little_stt` | `PAPER_VERIFIED_HF_MIRROR_UNAVAILABLE_404` | Levantine Arabic | Pediatric (6-13 years) | UNKNOWN_UNVERIFIED_FROM_PUBLIC_REPO (paper cites research release) | False | 0 |
| `arabic_speech_corpus` | `PUBLIC_HF_VERIFIED_LOCAL_SUBSET` | Modern Standard Arabic (Levantine/MSA speaker) | Adult (single speaker + expert phonetic alignment) | CC-BY-4.0 | True | 3 |
| `l2_ksu` | `RESTRICTED_LDC_MANUAL_OBTAIN_REQUIRED` | Modern Standard Arabic (native + L2 accents) | Adult | LDC User Agreement (LDC2024S11 — Restricted / Paid Membership or License) | False | 0 |
| `musan_noise` | `PUBLIC_VERIFIED_LOCAL_SUBSET` | Non-speech environmental noise (music/noise/babble subsets exist in full MUSAN) | N/A (non-speech) | CC-BY-4.0 | True | 5 |
| `future_egyptian_pediatric_private_collection` | `PLANNED_NOT_COLLECTED_PHASE0` | Egyptian Arabic (Cairene & regional target vocabulary) | Pediatric (3-10 years, stratified by age & speech-disorder profile) | Private Consented Clinical Research & Product Data (Parental Written Consent Required) | True | 0 |

## Stage Quotas
- **Stage A Calibration / Dev:** `2,000` target samples (`450` correct pediatric, `450` mispronounced, `350` noisy/weak pediatric, `400` adult Arabic, `250` noise/silence, `100` separated controlled synthetic).
- **Stage B Immutable Blind Holdout:** `1,500` target human-only samples (`450` correct pediatric, `450` mispronounced, `250` noisy/weak pediatric, `200` adult Arabic, `150` noise/silence, **`0` synthetic**).
- **Future Phase 5+ Pool (`130,000+` target):** Speaker/fingerprint firewalled from Stage A (`2,000`, Phase 1) and Stage B (`1,500`, Phase 4).
