"""Reusable Phase 0 Benchmark Metric Infrastructure with Wilson 95% CIs & speaker aggregation."""

from __future__ import annotations

import math
import re
from collections import Counter, defaultdict
from typing import Any, Sequence

import numpy as np

Z_95 = 1.959963984540054


def wilson_ci(successes: int, total: int, z: float = Z_95) -> dict[str, Any]:
    """Return exact rate and Wilson 95% confidence interval; returns None metrics when total == 0."""
    if total <= 0:
        return {"n": 0, "k": 0, "rate": None, "ci_low": None, "ci_high": None}
    p = successes / total
    denom = 1.0 + (z * z) / total
    center = (p + (z * z) / (2.0 * total)) / denom
    half = (z * math.sqrt((p * (1.0 - p) + (z * z) / (4.0 * total)) / total)) / denom
    return {
        "n": total,
        "k": successes,
        "rate": round(p, 6),
        "ci_low": round(max(0.0, center - half), 6),
        "ci_high": round(min(1.0, center + half), 6),
    }


def levenshtein_align(ref: Sequence[str], hyp: Sequence[str]) -> dict[str, Any]:
    """Exact Wagner-Fischer edit alignment tracking S/D/I counts and substitution pairs."""
    n, m = len(ref), len(hyp)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    bp = [[""] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        dp[i][0] = i
        bp[i][0] = "D"
    for j in range(1, m + 1):
        dp[0][j] = j
        bp[0][j] = "I"
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if ref[i - 1] == hyp[j - 1] else 1
            sub = dp[i - 1][j - 1] + cost
            dele = dp[i - 1][j] + 1
            ins = dp[i][j - 1] + 1
            best = min(sub, dele, ins)
            dp[i][j] = best
            if best == sub:
                bp[i][j] = "M" if cost == 0 else "S"
            elif best == dele:
                bp[i][j] = "D"
            else:
                bp[i][j] = "I"

    i, j = n, m
    subs = dels = ins = matches = 0
    confusions: list[tuple[str, str]] = []
    while i > 0 or j > 0:
        op = bp[i][j]
        if op == "M":
            matches += 1
            i -= 1
            j -= 1
        elif op == "S":
            subs += 1
            confusions.append((ref[i - 1], hyp[j - 1]))
            i -= 1
            j -= 1
        elif op == "D":
            dels += 1
            i -= 1
        else:
            ins += 1
            j -= 1

    dist = subs + dels + ins
    return {
        "distance": dist,
        "matches": matches,
        "substitutions": subs,
        "deletions": dels,
        "insertions": ins,
        "ref_len": n,
        "hyp_len": m,
        "error_rate": round(dist / max(1, n), 6),
        "confusions": confusions,
    }


def normalize_arabic_text(text: str) -> str:
    """Standard Arabic normalization (Alef forms, Teh Marbuta, Alef Maksura, diacritics removed)."""
    t = re.sub(r"[\u064B-\u065F\u0670]", "", text.strip())
    t = t.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    t = t.replace("ى", "ي").replace("ة", "ه")
    t = re.sub(r"[^\w\s\u0600-\u06FF]", " ", t)
    return " ".join(t.split()).lower()


def compute_vad_metrics(y_true_speech: Sequence[bool], y_pred_speech: Sequence[bool]) -> dict[str, Any]:
    if len(y_true_speech) != len(y_pred_speech):
        raise ValueError("VAD metric inputs must have matching lengths")
    tp = fp = tn = fn = 0
    for yt, yp in zip(y_true_speech, y_pred_speech):
        if yt and yp:
            tp += 1
        elif (not yt) and yp:
            fp += 1
        elif (not yt) and (not yp):
            tn += 1
        else:
            fn += 1
    recall = wilson_ci(tp, tp + fn)
    specificity = wilson_ci(tn, tn + fp)
    far = (fp / (tn + fp)) if (tn + fp) > 0 else None
    precision = (tp / (tp + fp)) if (tp + fp) > 0 else None
    f1 = (2 * tp / (2 * tp + fp + fn)) if (2 * tp + fp + fn) > 0 else None
    bal_acc = (
        0.5 * (recall["rate"] + specificity["rate"])
        if recall["rate"] is not None and specificity["rate"] is not None
        else None
    )
    return {
        "total": len(y_true_speech),
        "tp": tp,
        "fp": fp,
        "tn": tn,
        "fn": fn,
        "speech_recall": recall,
        "non_speech_specificity": specificity,
        "false_alarm_rate": round(far, 6) if far is not None else None,
        "precision": round(precision, 6) if precision is not None else None,
        "f1": round(f1, 6) if f1 is not None else None,
        "balanced_accuracy": round(bal_acc, 6) if bal_acc is not None else None,
    }


def _si_sdr(ref: np.ndarray, est: np.ndarray) -> float:
    ref_z = ref - np.mean(ref)
    est_z = est - np.mean(est)
    ref_energy = float(np.sum(ref_z ** 2))
    if ref_energy < 1e-12:
        return 0.0
    alpha = float(np.dot(est_z, ref_z)) / ref_energy
    s_target = alpha * ref_z
    e_noise = est_z - s_target
    num = float(np.sum(s_target ** 2)) + 1e-12
    den = float(np.sum(e_noise ** 2)) + 1e-12
    return 10.0 * math.log10(num / den)


def compute_noise_suppression_metrics(
    clean_signals: Sequence[np.ndarray],
    noisy_signals: Sequence[np.ndarray],
    enhanced_signals: Sequence[np.ndarray],
) -> dict[str, Any]:
    if not (len(clean_signals) == len(noisy_signals) == len(enhanced_signals)):
        raise ValueError("Noise suppression metric sequences must have equal length")
    if not clean_signals:
        return {"count": 0, "mean_input_sisdr_db": None, "mean_output_sisdr_db": None, "mean_sisdr_gain_db": None, "mean_clean_corr": None}

    in_sisdrs, out_sisdrs, gains, corrs = [], [], [], []
    for clean, noisy, enh in zip(clean_signals, noisy_signals, enhanced_signals):
        n = min(len(clean), len(noisy), len(enh))
        c, ns, en = clean[:n].astype(np.float64), noisy[:n].astype(np.float64), enh[:n].astype(np.float64)
        s_in = _si_sdr(c, ns)
        s_out = _si_sdr(c, en)
        in_sisdrs.append(s_in)
        out_sisdrs.append(s_out)
        gains.append(s_out - s_in)
        c_std = float(np.std(c))
        e_std = float(np.std(en))
        corrs.append(float(np.corrcoef(c, en)[0, 1]) if c_std > 1e-8 and e_std > 1e-8 else 0.0)
    return {
        "count": len(clean_signals),
        "mean_input_sisdr_db": round(float(np.mean(in_sisdrs)), 4),
        "mean_output_sisdr_db": round(float(np.mean(out_sisdrs)), 4),
        "mean_sisdr_gain_db": round(float(np.mean(gains)), 4),
        "mean_clean_corr": round(float(np.mean(corrs)), 4),
    }


def compute_stt_metrics(
    ref_texts: Sequence[str],
    hyp_texts: Sequence[str],
    is_non_speech: Sequence[bool] | None = None,
) -> dict[str, Any]:
    if len(ref_texts) != len(hyp_texts):
        raise ValueError("STT reference and hypothesis lists must match in length")
    flags = list(is_non_speech) if is_non_speech is not None else [False] * len(ref_texts)

    speech_word_err = speech_word_ref = 0
    speech_char_err = speech_char_ref = 0
    exact_hits = speech_count = 0
    non_speech_count = hallucinations = 0

    for ref, hyp, ns in zip(ref_texts, hyp_texts, flags):
        n_ref = normalize_arabic_text(ref)
        n_hyp = normalize_arabic_text(hyp)
        if ns:
            non_speech_count += 1
            if n_hyp:
                hallucinations += 1
            continue
        speech_count += 1
        if n_ref == n_hyp and n_ref != "":
            exact_hits += 1
        w_res = levenshtein_align(n_ref.split(), n_hyp.split())
        c_res = levenshtein_align(list(n_ref.replace(" ", "")), list(n_hyp.replace(" ", "")))
        speech_word_err += w_res["distance"]
        speech_word_ref += max(1, len(n_ref.split()))
        speech_char_err += c_res["distance"]
        speech_char_ref += max(1, len(n_ref.replace(" ", "")))

    return {
        "speech_samples": speech_count,
        "wer": round(speech_word_err / speech_word_ref, 6) if speech_word_ref else None,
        "cer": round(speech_char_err / speech_char_ref, 6) if speech_char_ref else None,
        "normalized_exact_match": wilson_ci(exact_hits, speech_count),
        "non_speech_samples": non_speech_count,
        "silence_noise_hallucination": wilson_ci(hallucinations, non_speech_count),
    }


def compute_phoneme_metrics(
    ref_sequences: Sequence[Sequence[str]],
    hyp_sequences: Sequence[Sequence[str]],
) -> dict[str, Any]:
    if len(ref_sequences) != len(hyp_sequences):
        raise ValueError("Phoneme reference and hypothesis lists must match")
    total_ref = total_hyp = total_subs = total_dels = total_ins = total_matches = exact_seq = 0
    confusion_counter: Counter[tuple[str, str]] = Counter()
    for ref, hyp in zip(ref_sequences, hyp_sequences):
        r_list = list(ref)
        h_list = list(hyp)
        if r_list == h_list and len(r_list) > 0:
            exact_seq += 1
        res = levenshtein_align(r_list, h_list)
        total_ref += res["ref_len"]
        total_hyp += res["hyp_len"]
        total_subs += res["substitutions"]
        total_dels += res["deletions"]
        total_ins += res["insertions"]
        total_matches += res["matches"]
        for pair in res["confusions"]:
            confusion_counter[pair] += 1

    dist = total_subs + total_dels + total_ins
    per = (dist / total_ref) if total_ref > 0 else None
    precision = (total_matches / total_hyp) if total_hyp > 0 else None
    recall = (total_matches / total_ref) if total_ref > 0 else None
    f1 = (2 * precision * recall / (precision + recall)) if precision and recall else (0.0 if (precision == 0.0 or recall == 0.0) else None)
    return {
        "utterances": len(ref_sequences),
        "total_ref_phonemes": total_ref,
        "total_hyp_phonemes": total_hyp,
        "per": round(per, 6) if per is not None else None,
        "substitution_rate": round(total_subs / total_ref, 6) if total_ref else None,
        "deletion_rate": round(total_dels / total_ref, 6) if total_ref else None,
        "insertion_rate": round(total_ins / total_ref, 6) if total_ref else None,
        "phoneme_precision": round(precision, 6) if precision is not None else None,
        "phoneme_recall": round(recall, 6) if recall is not None else None,
        "phoneme_f1": round(f1, 6) if f1 is not None else None,
        "sequence_exact_match": wilson_ci(exact_seq, len(ref_sequences)),
        "top_confusions": [{"ref": r, "hyp": h, "count": c} for (r, h), c in confusion_counter.most_common(15)],
    }


def compute_assessment_metrics(items: Sequence[dict[str, Any]]) -> dict[str, Any]:
    """Evaluate sample-level & speaker-level pronunciation acceptance/rejection, abstention & calibration.

    Each item requires: expected_pass (bool), predicted_pass (bool), optional speaker_id (str),
    optional abstained (bool), optional predicted_confidence (float | None).
    """
    tp = fp = tn = fn = abstained = 0
    by_speaker: dict[str, list[bool]] = defaultdict(list)
    brier_terms: list[float] = []

    for it in items:
        exp = bool(it["expected_pass"])
        pred = bool(it["predicted_pass"])
        is_abs = bool(it.get("abstained", False))
        if is_abs:
            abstained += 1
        correct = exp == pred
        spk = str(it.get("speaker_id") or "").strip()
        if spk and spk.lower() not in ("none", "n/a", "unknown"):
            by_speaker[spk].append(correct)

        if exp and pred:
            tp += 1
        elif (not exp) and pred:
            fp += 1
        elif (not exp) and (not pred):
            tn += 1
        else:
            fn += 1

        conf = it.get("predicted_confidence")
        if conf is not None:
            brier_terms.append((float(conf) - (1.0 if exp else 0.0)) ** 2)

    accept_rate = wilson_ci(tp, tp + fn)
    reject_rate = wilson_ci(tn, tn + fp)
    far = (fp / (tn + fp)) if (tn + fp) > 0 else None
    frr = (fn / (tp + fn)) if (tp + fn) > 0 else None
    bal_acc = (
        0.5 * (accept_rate["rate"] + reject_rate["rate"])
        if accept_rate["rate"] is not None and reject_rate["rate"] is not None
        else None
    )

    speaker_means = [sum(v) / len(v) for v in by_speaker.values() if v]
    speaker_macro_acc = round(sum(speaker_means) / len(speaker_means), 6) if speaker_means else None

    return {
        "total_samples": len(items),
        "true_accept_rate": accept_rate,
        "true_reject_rate": reject_rate,
        "false_acceptance_rate": round(far, 6) if far is not None else None,
        "false_rejection_rate": round(frr, 6) if frr is not None else None,
        "balanced_accuracy": round(bal_acc, 6) if bal_acc is not None else None,
        "abstention_rate": wilson_ci(abstained, len(items)),
        "speaker_count": len(speaker_means),
        "speaker_level_macro_accuracy": speaker_macro_acc,
        "brier_score": round(float(np.mean(brier_terms)), 6) if brier_terms else None,
    }


def compute_runtime_metrics(
    latencies_ms: Sequence[float],
    audio_durations_ms: Sequence[float],
    ram_mb_samples: Sequence[float] | None = None,
) -> dict[str, Any]:
    if not latencies_ms or len(latencies_ms) != len(audio_durations_ms):
        return {"count": 0, "latency_p50_ms": None, "latency_p95_ms": None, "mean_rtf": None, "peak_ram_mb": None}
    lat = np.array(latencies_ms, dtype=np.float64)
    dur = np.maximum(np.array(audio_durations_ms, dtype=np.float64), 1.0)
    rtf = lat / dur
    return {
        "count": len(latencies_ms),
        "cold_first_latency_ms": round(float(lat[0]), 2),
        "latency_p50_ms": round(float(np.percentile(lat, 50)), 2),
        "latency_p95_ms": round(float(np.percentile(lat, 95)), 2),
        "mean_rtf": round(float(np.mean(rtf)), 4),
        "peak_ram_mb": round(float(max(ram_mb_samples)), 2) if ram_mb_samples else None,
    }
