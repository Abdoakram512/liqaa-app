"""Phase 0 Data Leakage Prevention Engine: hashes, multi-scale speech fingerprints & split audits."""

from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np


TARGET_SR = 16000
PHYSICAL_HOP_SAMPLES = 256  # 16ms per frame @ 16kHz


@dataclass
class AudioSignature:
    sample_id: str
    file_path: str
    raw_file_sha256: str
    canonical_pcm_sha256: str
    duration_ms: int
    active_duration_ms: int
    sample_rate_hz: int
    rms: float
    is_near_silent: bool
    spectral_frames: np.ndarray  # shape (T, 14) physical-time normalized speech bands (250-3800Hz)
    energy_contour: np.ndarray   # shape (T,) normalized log-RMS temporal envelope
    mean_spectrum: np.ndarray    # shape (14,)


def read_wav_mono_16k(path: Path) -> tuple[np.ndarray, int, str]:
    """Decode RIFF/WAV (PCM 8/16/24/32 or IEEE float32) cleanly without model deps."""
    raw = path.read_bytes()
    raw_sha = hashlib.sha256(raw).hexdigest()
    if len(raw) < 44 or raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        raise ValueError(f"Unsupported or corrupt WAV header: {path}")

    pos = 12
    fmt_code = 1
    channels = 1
    sr = 16000
    bits = 16
    pcm_bytes = b""

    while pos + 8 <= len(raw):
        cid = raw[pos : pos + 4]
        csz = struct.unpack_from("<I", raw, pos + 4)[0]
        payload = raw[pos + 8 : pos + 8 + csz]
        if cid == b"fmt " and len(payload) >= 16:
            fmt_code, channels, sr, _, _, bits = struct.unpack_from("<HHIIHH", payload, 0)
        elif cid == b"data":
            pcm_bytes = payload
            break
        pos += 8 + csz + (csz % 2)

    if not pcm_bytes:
        raise ValueError(f"Missing WAV data chunk: {path}")

    if fmt_code == 3 and bits == 32:
        arr = np.frombuffer(pcm_bytes, dtype="<f4").astype(np.float32)
    elif fmt_code == 1 and bits == 16:
        arr = np.frombuffer(pcm_bytes, dtype="<i2").astype(np.float32) / 32768.0
    elif fmt_code == 1 and bits == 32:
        arr = np.frombuffer(pcm_bytes, dtype="<i4").astype(np.float32) / 2147483648.0
    elif fmt_code == 1 and bits == 24:
        b = np.frombuffer(pcm_bytes, dtype=np.uint8)
        n = len(b) // 3
        b = b[: n * 3].reshape(n, 3)
        signed = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        signed = np.where(signed >= 0x800000, signed - 0x1000000, signed)
        arr = signed.astype(np.float32) / 8388608.0
    elif fmt_code == 1 and bits == 8:
        arr = (np.frombuffer(pcm_bytes, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    else:
        raise ValueError(f"Unsupported WAV format code={fmt_code} bits={bits}: {path}")

    if channels > 1:
        n_frames = len(arr) // channels
        arr = arr[: n_frames * channels].reshape(n_frames, channels).mean(axis=1)

    arr = arr - float(np.mean(arr)) if len(arr) > 0 else arr

    if sr != TARGET_SR and len(arr) > 1:
        out_len = max(1, int(round(len(arr) * TARGET_SR / sr)))
        old_idx = np.arange(len(arr), dtype=np.float64)
        new_idx = np.linspace(0, len(arr) - 1, out_len, dtype=np.float64)
        arr = np.interp(new_idx, old_idx, arr).astype(np.float32)

    return np.clip(arr, -1.0, 1.0).astype(np.float32), sr, raw_sha


def _extract_active_core(samples_16k: np.ndarray) -> np.ndarray:
    """Strip leading/trailing silence reliably without truncating real low-energy tails."""
    if len(samples_16k) < 512:
        padded = np.zeros(512, dtype=np.float32)
        padded[: len(samples_16k)] = samples_16k
        return padded

    # Compute 20ms frame RMS to avoid being fooled by single sample clicks or zero padding
    win = 320
    hop = 160
    n_f = max(1, (len(samples_16k) - win) // hop + 1)
    frame_rms = np.array(
        [float(np.sqrt(np.mean(samples_16k[i * hop : i * hop + win] ** 2))) for i in range(n_f)],
        dtype=np.float32,
    )
    floor = float(np.percentile(frame_rms, 15))
    peak_rms = float(np.max(frame_rms))
    thresh = max(0.004, floor * 2.0, peak_rms * 0.12)
    active = np.where(frame_rms >= thresh)[0]
    if len(active) >= 2:
        lo = max(0, int(active[0]) * hop - 320)
        hi = min(len(samples_16k), int(active[-1]) * hop + win + 320)
        core = samples_16k[lo:hi]
    else:
        core = samples_16k

    if len(core) < 512:
        padded = np.zeros(512, dtype=np.float32)
        padded[: len(core)] = core
        core = padded
    return core


def _canonical_pcm_sha256(samples_16k: np.ndarray) -> str:
    """Hash silence-stripped, peak-normalized canonical 16kHz PCM16."""
    core = _extract_active_core(samples_16k)
    if len(core) == 0:
        return hashlib.sha256(b"").hexdigest()
    peak = float(np.max(np.abs(core)))
    norm = core / peak if peak > 1e-4 else core
    pcm16 = np.round(np.clip(norm, -1.0, 1.0) * 32767.0).astype("<i2")
    return hashlib.sha256(pcm16.tobytes()).hexdigest()


def _compute_physical_spectral_frames(core_16k: np.ndarray, n_bands: int = 14) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Compute physical-rate (16ms hop) spectral & log-energy frames across 250Hz-3800Hz."""
    win = 512
    hop = PHYSICAL_HOP_SAMPLES
    if len(core_16k) < win:
        padded = np.zeros(win, dtype=np.float32)
        padded[: len(core_16k)] = core_16k
        core_16k = padded

    n_frames = max(1, (len(core_16k) - win) // hop + 1)
    band_edges = np.unique(np.round(np.geomspace(8, 122, n_bands + 1)).astype(int))
    window = np.hanning(win).astype(np.float32)

    frames = []
    frame_energies = []
    for f_idx in range(n_frames):
        start = f_idx * hop
        seg = core_16k[start : start + win] * window
        rms = float(np.sqrt(np.mean(seg ** 2)))
        frame_energies.append(rms)
        mag = np.abs(np.fft.rfft(seg)) + 1e-6
        bands = np.zeros(n_bands, dtype=np.float32)
        for b in range(min(n_bands, len(band_edges) - 1)):
            s_i, e_i = band_edges[b], max(band_edges[b] + 1, band_edges[b + 1])
            bands[b] = float(np.log1p(np.mean(mag[s_i:e_i]) / max(rms, 1e-4)))
        bands = bands - float(np.mean(bands))
        norm = float(np.linalg.norm(bands)) + 1e-8
        frames.append(bands / norm)

    mat = np.stack(frames, axis=0)
    raw_env = np.array(frame_energies, dtype=np.float32)
    log_env = np.log1p(raw_env / (float(np.max(raw_env)) + 1e-6) * 20.0)
    weights = raw_env / (float(np.sum(raw_env)) + 1e-8)
    mean_spec = np.sum(mat * weights[:, None], axis=0)
    mean_norm = float(np.linalg.norm(mean_spec)) + 1e-8
    return mat, log_env, mean_spec / mean_norm


def extract_audio_signature(sample_id: str, file_path: Path) -> AudioSignature:
    samples_16k, orig_sr, raw_sha = read_wav_mono_16k(file_path)
    rms = float(np.sqrt(np.mean(samples_16k ** 2))) if len(samples_16k) else 0.0
    core = _extract_active_core(samples_16k)
    core_rms = float(np.sqrt(np.mean(core ** 2))) if len(core) else 0.0
    is_silent = core_rms < 0.002 or float(np.max(np.abs(samples_16k))) < 0.005
    canon_sha = _canonical_pcm_sha256(samples_16k)
    fp_mat, energy_env, mean_spec = _compute_physical_spectral_frames(core)
    dur_ms = int(round(len(samples_16k) * 1000.0 / TARGET_SR))
    active_ms = int(round(len(core) * 1000.0 / TARGET_SR))
    return AudioSignature(
        sample_id=sample_id,
        file_path=str(file_path),
        raw_file_sha256=raw_sha,
        canonical_pcm_sha256=canon_sha,
        duration_ms=dur_ms,
        active_duration_ms=active_ms,
        sample_rate_hz=orig_sr,
        rms=round(rms, 6),
        is_near_silent=is_silent,
        spectral_frames=fp_mat,
        energy_contour=energy_env,
        mean_spectrum=mean_spec,
    )


def _norm_corr(x: np.ndarray, y: np.ndarray) -> float:
    sx, sy = float(np.std(x)), float(np.std(y))
    if sx < 0.025 and sy < 0.025:
        return 1.0
    if sx < 0.025 or sy < 0.025:
        return 0.0
    xz = x - float(np.mean(x))
    yz = y - float(np.mean(y))
    denom = float(np.linalg.norm(xz) * np.linalg.norm(yz))
    if denom < 1e-8:
        return 0.0
    return float(np.dot(xz, yz) / denom)


def acoustic_similarity(a: AudioSignature, b: AudioSignature) -> float:
    """Compute joint spectral-trajectory + temporal-energy similarity resilient to padding/trim/resampling."""
    if a.is_near_silent or b.is_near_silent:
        return 0.0

    active_ratio = min(a.active_duration_ms, b.active_duration_ms) / max(1, max(a.active_duration_ms, b.active_duration_ms))
    if active_ratio < 0.30:
        return 0.0

    fa, fb = a.spectral_frames, b.spectral_frames
    ea, eb = a.energy_contour, b.energy_contour
    if len(fa) <= len(fb):
        s_f, l_f, s_e, l_e = fa, fb, ea, eb
    else:
        s_f, l_f, s_e, l_e = fb, fa, eb, ea

    ls, ll = len(s_f), len(l_f)
    # Require >= 16 active frames (~270ms) so tiny fragments don't create false-positive matches
    if ls < 16:
        return 0.0

    best_joint = -1.0
    stride = 1 if ll <= 180 else 2
    max_off = ll - ls
    for off in range(0, max_off + 1, stride):
        spec_sim = float(np.mean(np.sum(s_f * l_f[off : off + ls], axis=1)))
        env_corr = max(0.0, _norm_corr(s_e, l_e[off : off + ls]))
        joint = 0.65 * spec_sim + 0.35 * env_corr
        if joint > best_joint:
            best_joint = joint

    if max_off <= 6:
        for shift in (-3, -2, -1, 1, 2, 3):
            if shift > 0 and ls - shift >= 12:
                spec_sim = float(np.mean(np.sum(s_f[shift:] * l_f[: ls - shift], axis=1)))
                env_corr = max(0.0, _norm_corr(s_e[shift:], l_e[: ls - shift]))
                best_joint = max(best_joint, 0.65 * spec_sim + 0.35 * env_corr)
            elif shift < 0 and ls + shift >= 12:
                spec_sim = float(np.mean(np.sum(s_f[: ls + shift] * l_f[-shift : ls], axis=1)))
                env_corr = max(0.0, _norm_corr(s_e[: ls + shift], l_e[-shift : ls]))
                best_joint = max(best_joint, 0.65 * spec_sim + 0.35 * env_corr)

    mean_cos = float(np.dot(a.mean_spectrum, b.mean_spectrum))
    score = 0.85 * best_joint + 0.15 * mean_cos
    return max(0.0, min(1.0, score))


@dataclass
class LeakageFinding:
    finding_type: str
    severity: str
    split_pair: str
    sample_ids: list[str]
    detail: str
    recommended_action: str


@dataclass
class LeakageAuditReport:
    total_samples: int
    audio_files_hashed: int
    exact_file_duplicates: list[LeakageFinding] = field(default_factory=list)
    canonical_pcm_duplicates: list[LeakageFinding] = field(default_factory=list)
    acoustic_near_duplicates: list[LeakageFinding] = field(default_factory=list)
    speaker_overlaps: list[LeakageFinding] = field(default_factory=list)
    missing_speaker_records: list[LeakageFinding] = field(default_factory=list)
    session_overlaps: list[LeakageFinding] = field(default_factory=list)
    lineage_overlaps: list[LeakageFinding] = field(default_factory=list)
    cross_dataset_overlaps: list[LeakageFinding] = field(default_factory=list)
    transcript_overlaps: list[LeakageFinding] = field(default_factory=list)
    quarantined_sample_ids: list[str] = field(default_factory=list)
    thresholds: dict[str, Any] = field(default_factory=dict)

    @property
    def has_critical_leakage(self) -> bool:
        return bool(
            self.exact_file_duplicates
            or self.canonical_pcm_duplicates
            or self.acoustic_near_duplicates
            or self.speaker_overlaps
            or self.session_overlaps
            or self.lineage_overlaps
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "total_samples": self.total_samples,
            "audio_files_hashed": self.audio_files_hashed,
            "has_critical_leakage": self.has_critical_leakage,
            "counts": {
                "exact_file_duplicates": len(self.exact_file_duplicates),
                "canonical_pcm_duplicates": len(self.canonical_pcm_duplicates),
                "acoustic_near_duplicates": len(self.acoustic_near_duplicates),
                "speaker_overlaps": len(self.speaker_overlaps),
                "missing_speaker_records": len(self.missing_speaker_records),
                "session_overlaps": len(self.session_overlaps),
                "lineage_overlaps": len(self.lineage_overlaps),
                "cross_dataset_overlaps": len(self.cross_dataset_overlaps),
                "transcript_overlaps": len(self.transcript_overlaps),
                "quarantined_sample_ids": len(set(self.quarantined_sample_ids)),
            },
            "thresholds": self.thresholds,
            "exact_file_duplicates": [f.__dict__ for f in self.exact_file_duplicates],
            "canonical_pcm_duplicates": [f.__dict__ for f in self.canonical_pcm_duplicates],
            "acoustic_near_duplicates": [f.__dict__ for f in self.acoustic_near_duplicates],
            "speaker_overlaps": [f.__dict__ for f in self.speaker_overlaps],
            "missing_speaker_records": [f.__dict__ for f in self.missing_speaker_records],
            "session_overlaps": [f.__dict__ for f in self.session_overlaps],
            "lineage_overlaps": [f.__dict__ for f in self.lineage_overlaps],
            "cross_dataset_overlaps": [f.__dict__ for f in self.cross_dataset_overlaps],
            "transcript_overlaps": [f.__dict__ for f in self.transcript_overlaps],
            "quarantined_sample_ids": sorted(set(self.quarantined_sample_ids)),
        }


def is_non_speech_record(rec: dict[str, Any]) -> bool:
    atype = str(rec.get("audio_type", "")).strip().lower()
    cat = str(rec.get("category", "")).strip().lower()
    if atype in ("silence_floor", "environmental_noise", "noise_only", "non_speech", "controlled_synthetic"):
        return True
    if cat in ("silence_near_silence", "environmental_noise", "non_speech_noise_and_silence"):
        return True
    if rec.get("actual_speech_present") is False:
        return True
    return False


def _lsh_candidate_pairs(
    sig_list: list[AudioSignature],
    min_active_ratio: float = 0.30,
) -> tuple[list[tuple[int, int]], dict[str, Any]]:
    """Multi-table binary spectral + coarse duration bucketing to avoid O(N^2) exhaustive scans.

    Uses 4 overlapping quantization projections across mean_spectrum and active-thirds
    energy/spectral summaries, plus neighbor duration bins so silence-padded/trimmed variants
    retrieve together without dropping valid candidates.
    """
    n = len(sig_list)
    if n <= 1:
        return [], {"tables": 4, "candidate_pairs": 0, "exhaustive_pairs": 0}

    rng = np.random.default_rng(20260)
    proj = rng.normal(0.0, 1.0, size=(4, 8, 14)).astype(np.float32)

    tables: list[dict[tuple[int, int], list[int]]] = [{}, {}, {}, {}]
    for idx, sig in enumerate(sig_list):
        if sig.is_near_silent:
            continue
        dur_bin = int(np.floor(np.log2(max(50, sig.active_duration_ms) / 100.0)))
        # Build global + prefix + suffix summaries so trimmed prefixes/suffixes hash to same bucket in >=1 table
        fr = sig.spectral_frames
        vecs = [
            sig.mean_spectrum,
            np.mean(fr[: max(1, len(fr) // 2)], axis=0),
            np.mean(fr[len(fr) // 2 :], axis=0),
            np.mean(fr[max(0, len(fr) // 4) : max(1, (3 * len(fr)) // 4)], axis=0),
        ]
        for t_idx in range(4):
            bits = (vecs[t_idx] @ proj[t_idx].T) >= 0.0
            key_int = 0
            for b in bits:
                key_int = (key_int << 1) | int(bool(b))
            # Index into exact + +/-1 adjacent duration bins to preserve recall under 50% trimming
            for db in (dur_bin - 1, dur_bin, dur_bin + 1):
                tables[t_idx].setdefault((db, key_int), []).append(idx)

    pair_set: set[tuple[int, int]] = set()
    for tbl in tables:
        for bucket in tbl.values():
            if len(bucket) < 2 or len(bucket) > 64:
                # Cap overly broad degenerate buckets cleanly, though non-silent speech stays diverse
                bucket = bucket[:64]
            for a_i in range(len(bucket)):
                ia = bucket[a_i]
                for b_i in range(a_i + 1, len(bucket)):
                    ib = bucket[b_i]
                    lo, hi = (ia, ib) if ia < ib else (ib, ia)
                    if lo == hi:
                        continue
                    sa, sb = sig_list[lo], sig_list[hi]
                    ratio = min(sa.active_duration_ms, sb.active_duration_ms) / max(
                        1, max(sa.active_duration_ms, sb.active_duration_ms)
                    )
                    if ratio >= min_active_ratio:
                        pair_set.add((lo, hi))

    candidates = sorted(pair_set)
    stats = {
        "tables": 4,
        "candidate_pairs": len(candidates),
        "exhaustive_pairs": n * (n - 1) // 2,
    }
    return candidates, stats


def evaluate_indexed_recall(
    records: list[dict[str, Any]],
    audio_root: Path,
    acoustic_sim_threshold: float = 0.82,
) -> dict[str, Any]:
    """Compare LSH candidate retrieval against exhaustive pairwise reference on small sets."""
    sigs: list[AudioSignature] = []
    for rec in records:
        rel_path = rec.get("file_path") or rec.get("path") or ""
        full_path = (audio_root / rel_path) if rel_path and not Path(rel_path).is_absolute() else Path(rel_path)
        if rel_path and full_path.exists():
            sigs.append(extract_audio_signature(rec["sample_id"], full_path))

    exact_hits: set[tuple[str, str]] = set()
    for i in range(len(sigs)):
        if sigs[i].is_near_silent:
            continue
        for j in range(i + 1, len(sigs)):
            if sigs[j].is_near_silent:
                continue
            if acoustic_similarity(sigs[i], sigs[j]) >= acoustic_sim_threshold:
                a, b = sigs[i].sample_id, sigs[j].sample_id
                exact_hits.add((min(a, b), max(a, b)))

    cand_idx_pairs, idx_stats = _lsh_candidate_pairs(sigs)
    indexed_hits: set[tuple[str, str]] = set()
    for i, j in cand_idx_pairs:
        if acoustic_similarity(sigs[i], sigs[j]) >= acoustic_sim_threshold:
            a, b = sigs[i].sample_id, sigs[j].sample_id
            indexed_hits.add((min(a, b), max(a, b)))

    recalled = len(exact_hits & indexed_hits)
    recall = (recalled / len(exact_hits)) if exact_hits else 1.0
    return {
        "exhaustive_hits": len(exact_hits),
        "indexed_hits": len(indexed_hits),
        "recall": round(recall, 4),
        "missed_pairs": sorted(exact_hits - indexed_hits),
        **idx_stats,
    }


def run_leakage_audit(
    records: list[dict[str, Any]],
    audio_root: Path,
    acoustic_sim_threshold: float = 0.82,
    check_within_split_duplicates: bool = True,
    use_indexed_search: bool | None = None,
) -> LeakageAuditReport:
    """Audit split records for exact/near duplicates, missing speakers, speaker/session/lineage & transcript leakage."""
    report = LeakageAuditReport(
        total_samples=len(records),
        audio_files_hashed=0,
        thresholds={
            "acoustic_cosine_threshold": acoustic_sim_threshold,
            "min_active_duration_ratio": 0.25,
            "speech_band_hz": "250-3800Hz",
            "near_silent_rms_floor": 0.002,
            "known_limitations": (
                "Pure silence/white-noise fixtures are excluded from acoustic similarity to avoid FPs; "
                "severe <=5 dB additive noise alters clean formants and still requires parent_source_id lineage."
            ),
        },
    )

    signatures: dict[str, AudioSignature] = {}
    by_raw_hash: dict[str, list[dict[str, Any]]] = {}
    by_canon_hash: dict[str, list[dict[str, Any]]] = {}
    by_speaker: dict[str, list[dict[str, Any]]] = {}
    by_session: dict[str, list[dict[str, Any]]] = {}
    by_lineage: dict[str, list[dict[str, Any]]] = {}
    by_transcript: dict[str, list[dict[str, Any]]] = {}
    missing_spk_ids: list[str] = []

    for rec in records:
        sid = rec["sample_id"]
        rel_path = rec.get("file_path") or rec.get("path") or ""
        full_path = (audio_root / rel_path) if rel_path and not Path(rel_path).is_absolute() else Path(rel_path)

        if rel_path and full_path.exists() and full_path.is_file():
            sig = extract_audio_signature(sid, full_path)
            signatures[sid] = sig
            report.audio_files_hashed += 1
            by_raw_hash.setdefault(sig.raw_file_sha256, []).append(rec)
            if not sig.is_near_silent:
                by_canon_hash.setdefault(sig.canonical_pcm_sha256, []).append(rec)
        elif rec.get("sha256"):
            by_raw_hash.setdefault(rec["sha256"], []).append(rec)

        spk = str(rec.get("speaker_id", "")).strip()
        if not spk or spk.lower() in ("none", "n/a", "unknown"):
            if not is_non_speech_record(rec):
                missing_spk_ids.append(sid)
        else:
            by_speaker.setdefault(spk, []).append(rec)

        sess = str(rec.get("session_id", "")).strip()
        if sess and sess.lower() not in ("none", "n/a", "unknown"):
            by_session.setdefault(sess, []).append(rec)

        parent = str(rec.get("parent_source_id", rec.get("source_sample_id", ""))).strip()
        root_lineage = parent if parent else sid
        by_lineage.setdefault(root_lineage, []).append(rec)

        txt = str(rec.get("transcript") or rec.get("actual_spoken_word") or "").strip()
        if len(txt.split()) >= 3:
            norm_txt = " ".join(txt.lower().split())
            by_transcript.setdefault(norm_txt, []).append(rec)

    if missing_spk_ids:
        report.missing_speaker_records.append(
            LeakageFinding(
                finding_type="missing_or_unknown_speaker_id",
                severity="HIGH",
                split_pair="unverified_identity",
                sample_ids=missing_spk_ids,
                detail=f"{len(missing_spk_ids)} speech records lack valid speaker_id; cannot certify speaker disjointness.",
                recommended_action="Block from Stage B freeze until verified speaker_id assigned.",
            )
        )

    # 1. Exact file SHA-256 duplicates
    for h, grp in by_raw_hash.items():
        if len(grp) > 1:
            splits = sorted({r.get("split", "unassigned") for r in grp})
            if len(splits) > 1 or check_within_split_duplicates:
                ids = [r["sample_id"] for r in grp]
                report.exact_file_duplicates.append(
                    LeakageFinding(
                        finding_type="exact_file_sha256_duplicate",
                        severity="CRITICAL",
                        split_pair=",".join(splits),
                        sample_ids=ids,
                        detail=f"Identical raw file SHA-256 {h[:16]}... across {len(grp)} records.",
                        recommended_action="Quarantine duplicate copies and retain only 1 canonical entry in a single split.",
                    )
                )
                report.quarantined_sample_ids.extend(ids[1:])

    # 2. Canonical PCM duplicates (silence-trimmed header/gain/container invariant)
    for h, grp in by_canon_hash.items():
        if len(grp) > 1:
            raw_hashes = {signatures[r["sample_id"]].raw_file_sha256 for r in grp if r["sample_id"] in signatures}
            if len(raw_hashes) > 1 or len({r.get("split", "unassigned") for r in grp}) > 1:
                splits = sorted({r.get("split", "unassigned") for r in grp})
                ids = [r["sample_id"] for r in grp]
                report.canonical_pcm_duplicates.append(
                    LeakageFinding(
                        finding_type="canonical_pcm_duplicate",
                        severity="CRITICAL",
                        split_pair=",".join(splits),
                        sample_ids=ids,
                        detail=f"Identical normalized active-speech 16kHz PCM hash {h[:16]} (silence-pad / gain / container variant).",
                        recommended_action="Quarantine derived duplicate.",
                    )
                )
                report.quarantined_sample_ids.extend(ids[1:])

    # 3. Acoustic near-duplicate scan (indexed LSH candidate retrieval for large N; exact pairwise for small reference sets)
    sig_list = list(signatures.values())
    rec_by_id = {r["sample_id"]: r for r in records}
    seen_pairs: set[tuple[str, str]] = set()
    use_lsh = use_indexed_search if use_indexed_search is not None else (len(sig_list) > 250)
    if use_lsh:
        cand_pairs, idx_stats = _lsh_candidate_pairs(sig_list)
        report.thresholds["search_strategy"] = f"multi_probe_lsh ({idx_stats['candidate_pairs']}/{idx_stats['exhaustive_pairs']} candidate pairs)"
    else:
        cand_pairs = [
            (i, j)
            for i in range(len(sig_list))
            for j in range(i + 1, len(sig_list))
        ]
        report.thresholds["search_strategy"] = f"exhaustive_reference ({len(cand_pairs)} pairs)"

    for i, j in cand_pairs:
        sa = sig_list[i]
        sb = sig_list[j]
        if sa.is_near_silent or sb.is_near_silent:
            continue
        if sa.raw_file_sha256 == sb.raw_file_sha256 or sa.canonical_pcm_sha256 == sb.canonical_pcm_sha256:
            continue
        sim = acoustic_similarity(sa, sb)
        if sim >= acoustic_sim_threshold:
            pair_key = (min(sa.sample_id, sb.sample_id), max(sa.sample_id, sb.sample_id))
            if pair_key in seen_pairs:
                continue
            seen_pairs.add(pair_key)
            ra, rb = rec_by_id[sa.sample_id], rec_by_id[sb.sample_id]
            splits = sorted({ra.get("split", "unassigned"), rb.get("split", "unassigned")})
            if len(splits) > 1 or check_within_split_duplicates:
                report.acoustic_near_duplicates.append(
                    LeakageFinding(
                        finding_type="acoustic_fingerprint_near_duplicate",
                        severity="HIGH" if len(splits) > 1 else "MEDIUM",
                        split_pair=",".join(splits),
                        sample_ids=[sa.sample_id, sb.sample_id],
                        detail=f"Spectral envelope similarity={sim:.3f} >= {acoustic_sim_threshold} (resampling/trim/noise variant).",
                        recommended_action="Merge under single parent_source_id group and quarantine cross-split duplicate.",
                    )
                )
                report.quarantined_sample_ids.append(sb.sample_id)

            ds_a = ra.get("dataset_id", ra.get("original_dataset", ""))
            ds_b = rb.get("dataset_id", rb.get("original_dataset", ""))
            if ds_a != ds_b:
                report.cross_dataset_overlaps.append(
                    LeakageFinding(
                        finding_type="cross_dataset_acoustic_overlap",
                        severity="CRITICAL",
                        split_pair=f"{ds_a} <-> {ds_b}",
                        sample_ids=[sa.sample_id, sb.sample_id],
                        detail=f"Same acoustic clip appears across distinct datasets ({sim:.3f}).",
                        recommended_action="Exclude overlapping clip from Stage B Blind Holdout.",
                    )
                )

    # 4. Speaker overlap across splits & datasets
    for spk, grp in by_speaker.items():
        splits = sorted({r.get("split", "unassigned") for r in grp})
        if len(splits) > 1:
            ids = [r["sample_id"] for r in grp]
            report.speaker_overlaps.append(
                LeakageFinding(
                    finding_type="speaker_cross_split_leakage",
                    severity="CRITICAL",
                    split_pair=",".join(splits),
                    sample_ids=ids,
                    detail=f"Speaker '{spk}' appears across multiple splits: {splits}.",
                    recommended_action="Assign ALL recordings of speaker exclusively to one split.",
                )
            )
            report.quarantined_sample_ids.extend(ids)
        datasets = sorted({r.get("dataset_id", r.get("original_dataset", "")) for r in grp})
        if len(datasets) > 1:
            report.cross_dataset_overlaps.append(
                LeakageFinding(
                    finding_type="cross_dataset_speaker_overlap",
                    severity="HIGH",
                    split_pair=",".join(datasets),
                    sample_ids=[r["sample_id"] for r in grp],
                    detail=f"Speaker '{spk}' shared across datasets: {datasets}.",
                    recommended_action="Group datasets for this speaker during split assignment.",
                )
            )

    # 5. Session overlap across splits
    for sess, grp in by_session.items():
        splits = sorted({r.get("split", "unassigned") for r in grp})
        if len(splits) > 1:
            ids = [r["sample_id"] for r in grp]
            report.session_overlaps.append(
                LeakageFinding(
                    finding_type="recording_session_cross_split_leakage",
                    severity="CRITICAL",
                    split_pair=",".join(splits),
                    sample_ids=ids,
                    detail=f"Session '{sess}' spans multiple splits: {splits}.",
                    recommended_action="Keep entire recording session in one split.",
                )
            )
            report.quarantined_sample_ids.extend(ids)

    # 6. Parent-child augmentation / remix lineage overlap across splits
    for lineage_id, grp in by_lineage.items():
        if len(grp) > 1:
            splits = sorted({r.get("split", "unassigned") for r in grp})
            if len(splits) > 1:
                ids = [r["sample_id"] for r in grp]
                report.lineage_overlaps.append(
                    LeakageFinding(
                        finding_type="augmentation_lineage_cross_split_leakage",
                        severity="CRITICAL",
                        split_pair=",".join(splits),
                        sample_ids=ids,
                        detail=f"Derived audio copies sharing parent_source_id='{lineage_id}' cross splits: {splits}.",
                        recommended_action="Quarantine derived Stage B copy immediately.",
                    )
                )
                report.quarantined_sample_ids.extend(ids)

    # 7. Sentence transcript overlap across splits (>=3 words)
    for norm_txt, grp in by_transcript.items():
        splits = sorted({r.get("split", "unassigned") for r in grp})
        if len(splits) > 1:
            report.transcript_overlaps.append(
                LeakageFinding(
                    finding_type="multiword_transcript_cross_split_overlap",
                    severity="MEDIUM",
                    split_pair=",".join(splits),
                    sample_ids=[r["sample_id"] for r in grp],
                    detail=f"Identical multi-word utterance text shared across splits: '{norm_txt[:50]}'.",
                    recommended_action="Track sentence-disjoint generalization separately from prompted vocabulary.",
                )
            )

    return report
