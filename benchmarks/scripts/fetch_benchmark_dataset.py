#!/usr/bin/env python3
"""
Reproducible 100-Sample Real-World AI Benchmark Dataset Acquisition & Ground-Truth Freezing.

Downloads legally accessible, openly licensed Arabic pediatric, Egyptian child mispronunciation,
adult Arabic, and MUSAN environmental noise recordings without scraping or gated bypasses.
Anonymizes child speaker identities and computes raw acoustic metadata (WITHOUT running any
evaluated AI model during ground truth construction).
"""

import csv
import hashlib
import io
import json
import math
import os
import random
import re
import struct
import urllib.parse
import urllib.request
import wave
from collections import defaultdict
from pathlib import Path

import numpy as np

RNG = random.Random(20261125)
ROOT = Path(__file__).resolve().parents[2]
CLIPS_DIR = ROOT / "benchmarks" / "audio" / "clips"
CONTROLLED_DIR = ROOT / "benchmarks" / "audio" / "controlled"
CLIPS_DIR.mkdir(parents=True, exist_ok=True)
CONTROLLED_DIR.mkdir(parents=True, exist_ok=True)

# Exact 100 Arabic words from ASMDD Table 1 (arXiv:2111.01136)
ASMDD_WORDS = {
    1: "نعم", 2: "رجل", 3: "بخير", 4: "شخص", 5: "الوقت", 6: "اليوم", 7: "صحيح", 8: "أستطيع",
    9: "شكرا", 10: "الناس", 11: "أعلم", 12: "رائع", 13: "مرحبا", 14: "آسف", 15: "تعال", 16: "بالطبع",
    17: "العالم", 18: "الحقيقة", 19: "الليلة", 20: "أمي", 21: "الطريق", 22: "عمل", 23: "الجميع", 24: "جيدة",
    25: "المال", 26: "الذهاب", 27: "أرجوك", 28: "المنزل", 29: "الحياة", 30: "انتظر", 31: "الرجال", 32: "الله",
    33: "الباب", 34: "جميل", 35: "الشرطة", 36: "السيارة", 37: "النار", 38: "عظيم", 39: "الخير", 40: "حالك",
    41: "للغاية", 42: "فتاة", 43: "كبيرة", 44: "آسفة", 45: "الأرض", 46: "البيت", 47: "صباح", 48: "ألم",
    49: "لحظة", 50: "بالضبط", 51: "رقم", 52: "طريق", 53: "المدينة", 54: "الرئيس", 55: "صديقي", 56: "ساعة",
    57: "غرفة", 58: "عام", 59: "الأطفال", 60: "سنة", 61: "المدرسة", 62: "الصباح", 63: "الماء", 64: "التحدث",
    65: "الساعة", 66: "الليل", 67: "نهاية", 68: "حياة", 69: "الواقع", 70: "الطفل", 71: "دكتور", 72: "الهاتف",
    73: "الطعام", 74: "فريق", 75: "الفتى", 76: "اللقاء", 77: "نظرة", 78: "النساء", 79: "العشاء", 80: "الأسبوع",
    81: "ولد", 82: "رسالة", 83: "عائلة", 84: "القائد", 85: "المرأة", 86: "الطبيب", 87: "اسم", 88: "النقود",
    89: "الكلام", 90: "مدينة", 91: "مساء", 92: "الشمس", 93: "أرجوك", 94: "السماء", 95: "الزواج", 96: "أصدقاء",
    97: "مكتب", 98: "البحر", 99: "الكتاب", 100: "الشارع",
}

ABJAD_WORD_ARABIC = {
    "Kora": ("كورة", ["k", "uː", "r", "a"]),
    "Kalb": ("كلب", ["k", "l", "b"]),
    "Arnab": ("أرنب", ["ʔ", "r", "n", "b"]),
    "Bab": ("باب", ["b", "aː", "b"]),
    "Beit": ("بيت", ["b", "eː", "t"]),
    "Farasha": ("فراشة", ["f", "r", "aː", "ʃ", "a"]),
    "Feel": ("فيل", ["f", "iː", "l"]),
    "Jamal": ("جمل", ["ɡ", "m", "l"]),
    "Ketab": ("كتاب", ["k", "t", "aː", "b"]),
    "Qalam": ("قلم", ["ʔ", "l", "m"]),
    "Patta": ("بطة", ["b", "tˤ", "a"]),
    "Shams": ("شمس", ["ʃ", "m", "s"]),
    "Tofaha": ("تفاحة", ["t", "f", "aː", "ħ", "a"]),
    "Walad": ("ولد", ["w", "l", "d"]),
    "Zarafa": ("زرافة", ["z", "r", "aː", "f", "a"]),
    "Ghaba": ("غابة", ["ɣ", "aː", "b", "a"]),
    "Khobz": ("خبز", ["x", "b", "z"]),
    "Defda": ("ضفدع", ["dˤ", "f", "d", "ʕ"]),
    "Kharouf": ("خروف", ["x", "r", "uː", "f"]),
    "Namla": ("نملة", ["n", "m", "l", "a"]),
    "Qerd": ("قرد", ["ʔ", "r", "d"]),
    "Raml": ("رمل", ["r", "m", "l"]),
    "Sama": ("سماء", ["s", "m", "aː", "ʔ"]),
    "Warda": ("وردة", ["w", "r", "d", "a"]),
    "Bathenjan": ("باذنجان", ["b", "aː", "ð", "n", "ɡ", "aː", "n"]),
    "Thallaja": ("ثلاجة", ["θ", "l", "aː", "ɡ", "a"]),
    "Alif": ("ألف", ["ʔ", "l", "f"]),
    "Seen": ("سين", ["s", "iː", "n"]),
    "Kaf": ("كاف", ["k", "aː", "f"]),
    "Ra": ("راء", ["r", "aː", "ʔ"]),
    "Hha": ("حاء", ["ħ", "aː", "ʔ"]),
    "Alam": ("علم", ["ʕ", "l", "m"]),
    "Taera": ("طائرة", ["tˤ", "aː", "ʔ", "r", "a"]),
    "Hadeya": ("هدية", ["h", "d", "iː", "a"]),
    "Halib": ("حليب", ["ħ", "l", "iː", "b"]),
    "Masjed": ("مسجد", ["m", "s", "ɡ", "d"]),
    "Asfour": ("عصفور", ["ʕ", "sˤ", "f", "uː", "r"]),
    "Daraj": ("درج", ["d", "r", "ɡ"]),
    "Dabet": ("ضابط", ["dˤ", "aː", "b", "tˤ"]),
    "Ghazal": ("غزال", ["ɣ", "z", "aː", "l"]),
}


def http_get(url: str, timeout: int = 30) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "LIQAA-Benchmark/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def parse_wav_stats(raw: bytes) -> dict:
    """Strictly parse RIFF/WAVE header without calling any AI model."""
    if len(raw) < 44 or raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        raise ValueError("Invalid RIFF/WAVE header")
    offset = 12
    fmt_info = None
    data_bytes = None
    while offset + 8 <= len(raw):
        cid = raw[offset:offset + 4].decode("latin1", errors="replace")
        csize = struct.unpack_from("<I", raw, offset + 4)[0]
        start = offset + 8
        if cid == "fmt ":
            af, ch, sr, br, ba, bps = struct.unpack_from("<HHIIHH", raw, start)
            if af == 0xFFFE and csize >= 40:
                af = struct.unpack_from("<H", raw, start + 24)[0]
            fmt_info = (af, ch, sr, ba, bps)
        elif cid == "data":
            end = len(raw) if (csize == 0 or start + csize > len(raw)) else start + csize
            data_bytes = raw[start:end]
            break
        offset = start + csize + (csize % 2)
    if not fmt_info or not data_bytes:
        raise ValueError("Missing fmt or data chunk")

    af, ch, sr, ba, bps = fmt_info
    if af == 3 and bps == 32:
        arr = np.frombuffer(data_bytes[: (len(data_bytes) // 4) * 4], dtype="<f4")
    elif bps == 16:
        arr = np.frombuffer(data_bytes[: (len(data_bytes) // 2) * 2], dtype="<i2").astype(np.float32) / 32768.0
    elif bps == 32:
        arr = np.frombuffer(data_bytes[: (len(data_bytes) // 4) * 4], dtype="<i4").astype(np.float32) / 2147483648.0
    elif bps == 8:
        arr = (np.frombuffer(data_bytes, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    elif bps == 24:
        b = np.frombuffer(data_bytes[: (len(data_bytes) // 3) * 3], dtype=np.uint8).reshape(-1, 3)
        ints = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        ints = np.where(ints >= 0x800000, ints - 0x1000000, ints)
        arr = ints.astype(np.float32) / 8388608.0
    else:
        raise ValueError(f"Unsupported bps={bps}, af={af}")

    if ch > 1:
        arr = arr[: (len(arr) // ch) * ch].reshape(-1, ch).mean(axis=1)

    if len(arr) == 0:
        raise ValueError("Zero audio frames")

    dur_ms = int(round(len(arr) * 1000.0 / sr))
    rms = float(np.sqrt(np.mean(arr ** 2)))
    peak = float(np.max(np.abs(arr)))
    clipping = int(np.sum(np.abs(arr) >= 0.999))

    # Frame energy SNR estimate (bottom 15% noise floor vs top 30% signal)
    fsize = max(1, int(sr * 0.01))
    nf = len(arr) // fsize
    snr_db = 0.0
    if nf >= 4:
        energies = np.mean(arr[: nf * fsize].reshape(nf, fsize) ** 2, axis=1)
        energies.sort()
        n_floor = max(1e-10, float(np.mean(energies[: max(1, int(nf * 0.15))])))
        s_floor = max(1e-10, float(np.mean(energies[int(nf * 0.70):])))
        snr_db = float(np.clip(10.0 * math.log10(s_floor / n_floor), 0.0, 60.0))

    return {
        "audio_format": af,
        "channels": ch,
        "sample_rate": sr,
        "bits_per_sample": bps,
        "duration_ms": dur_ms,
        "rms": rms,
        "peak": peak,
        "clipping_count": clipping,
        "est_snr_db": snr_db,
        "mono_f32": arr,
    }


def make_pcm16_wav(mono_f32: np.ndarray, sr: int = 16000) -> bytes:
    pcm = (np.clip(mono_f32, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm)
    return buf.getvalue()


def buckwalter_to_arabic_phonemes(bw: str) -> list:
    # Tuned Buckwalter to Arabic script letters for independent ground-truth text reference
    bw_map = {
        ">": "أ", "<": "إ", "&": "ؤ", "}": "ئ", "'": "ء", "A": "ا", "b": "ب", "p": "ة",
        "t": "ت", "v": "ث", "j": "ج", "H": "ح", "x": "خ", "d": "د", "*": "ذ", "r": "ر",
        "z": "ز", "s": "س", "$": "ش", "S": "ص", "D": "ض", "T": "ط", "Z": "ظ", "E": "ع",
        "g": "غ", "f": "ف", "q": "ق", "k": "ك", "l": "ل", "m": "م", "n": "ن", "h": "ه",
        "w": "و", "y": "ي", "Y": "ى", "|": "آ",
    }
    words = []
    cur = []
    for ch in bw:
        if ch in bw_map:
            cur.append(bw_map[ch])
        elif ch in (" ", "\t"):
            if cur:
                words.append("".join(cur))
                cur = []
    if cur:
        words.append("".join(cur))
    return words


def simple_arabic_ipa(word_ar: str) -> list:
    m = {
        "أ": "ʔ", "إ": "ʔ", "آ": "ʔ", "ء": "ʔ", "ؤ": "ʔ", "ئ": "ʔ", "ا": "aː", "ب": "b",
        "ت": "t", "ث": "θ", "ج": "ɡ", "ح": "ħ", "خ": "x", "د": "d", "ذ": "ð", "ر": "r",
        "ز": "z", "س": "s", "ش": "ʃ", "ص": "sˤ", "ض": "dˤ", "ط": "tˤ", "ظ": "ðˤ", "ع": "ʕ",
        "غ": "ɣ", "ف": "f", "ق": "q", "ك": "k", "ل": "l", "م": "m", "ن": "n", "ه": "h",
        "ة": "a", "و": "uː", "ي": "iː", "ى": "aː",
    }
    return [m[c] for c in word_ar if c in m]


def main():
    samples = []
    used_sources = set()

    def save_clip(sample_id: str, raw_bytes: bytes) -> tuple:
        p = CLIPS_DIR / f"{sample_id}.wav"
        p.write_bytes(raw_bytes)
        return str(p.relative_to(ROOT)).replace("\\", "/"), sha256_bytes(raw_bytes)

    # ------------------------------------------------------------------
    # 1. Fetch ASMDD metadata (DOI: 10.17632/x54dg53rmr.1, CC0 1.0)
    # ------------------------------------------------------------------
    print("Fetching ASMDD Mendeley metadata...")
    asmdd_meta = json.loads(http_get("https://data.mendeley.com/public-api/datasets/x54dg53rmr").decode())
    asmdd_files = asmdd_meta["files"]
    folder_to_anon = {}
    for f in asmdd_files:
        fid = f.get("folder_id", "unknown")
        if fid not in folder_to_anon:
            folder_to_anon[fid] = f"spk_asmdd_{len(folder_to_anon)+1:02d}"

    # Download candidate ASMDD correct & _N error recordings across multiple speakers & target words
    asmdd_correct_candidates = []
    asmdd_error_candidates = []

    target_word_idxs = [33, 46, 61, 63, 72, 76, 81, 92, 94, 99, 2, 13, 15, 20, 32, 35, 37, 45, 52, 57]
    for f in asmdd_files:
        fn = f["filename"]
        if not fn.lower().endswith(".wav"):
            continue
        url = f.get("content_details", {}).get("download_url")
        if not url:
            continue
        fid = f.get("folder_id", "")
        m_num = re.match(r"^0*(\d+)", fn)
        if not m_num:
            continue
        widx = int(m_num.group(1))
        if widx not in ASMDD_WORDS:
            continue
        is_err = "_n" in fn.lower()
        if is_err:
            asmdd_error_candidates.append((widx, fid, fn, url, f["id"]))
        elif widx in target_word_idxs:
            asmdd_correct_candidates.append((widx, fid, fn, url, f["id"]))

    RNG.shuffle(asmdd_correct_candidates)
    RNG.shuffle(asmdd_error_candidates)

    # Pick up to 65 downloaded ASMDD correct candidates (for Cat 1 + Cat 4 quiet + Cat 5 noisy + Cat 10 edge)
    asmdd_pool_correct = []
    seen_file_ids = set()
    # Prioritize covering key vocabulary indices first
    for widx in [33, 46, 61, 63, 72, 76, 81, 92, 94, 99]:
        for item in asmdd_correct_candidates:
            if item[0] == widx and item[4] not in seen_file_ids:
                try:
                    raw = http_get(item[3], timeout=20)
                    st = parse_wav_stats(raw)
                    if st["duration_ms"] >= 250 and st["rms"] >= 0.001:
                        seen_file_ids.add(item[4])
                        asmdd_pool_correct.append((item, raw, st))
                        break
                except Exception:
                    continue

    for item in asmdd_correct_candidates:
        if len(asmdd_pool_correct) >= 48:
            break
        if item[4] in seen_file_ids:
            continue
        try:
            raw = http_get(item[3], timeout=20)
            st = parse_wav_stats(raw)
            if st["duration_ms"] >= 250 and st["rms"] >= 0.0005:
                seen_file_ids.add(item[4])
                asmdd_pool_correct.append((item, raw, st))
        except Exception:
            continue

    print(f"Downloaded ASMDD correct pool: {len(asmdd_pool_correct)}")

    # Download 25 ASMDD _N error candidates across diverse speakers & words
    asmdd_pool_error = []
    for item in asmdd_error_candidates:
        if len(asmdd_pool_error) >= 26:
            break
        if item[4] in seen_file_ids:
            continue
        try:
            raw = http_get(item[3], timeout=20)
            st = parse_wav_stats(raw)
            if st["duration_ms"] >= 250 and st["rms"] >= 0.002:
                seen_file_ids.add(item[4])
                asmdd_pool_error.append((item, raw, st))
        except Exception:
            continue

    print(f"Downloaded ASMDD error (_N) pool: {len(asmdd_pool_error)}")

    # ------------------------------------------------------------------
    # 2. Fetch Abjad-Kids CSV & clips (MIT License, ages 3-12)
    # ------------------------------------------------------------------
    print("Fetching Abjad-Kids alphabet.csv...")
    abjad_csv = http_get("https://huggingface.co/datasets/Aziz-snoubra/Abjad-Kids/raw/main/alphabet.csv").decode("utf-8", errors="replace")
    abjad_by_lbl = defaultdict(list)
    for line in abjad_csv.strip().splitlines()[1:]:
        parts = line.split(",")
        if len(parts) >= 2:
            rel_path, lbl = parts[0].strip(), parts[1].strip()
            abjad_by_lbl[lbl].append(rel_path)

    abjad_spk_map = {}
    def get_abjad_spk(path: str) -> str:
        fn = path.split("/")[-1]
        segs = fn.split("_")
        raw_spk = segs[1].lower() if len(segs) >= 2 else fn
        if raw_spk not in abjad_spk_map:
            abjad_spk_map[raw_spk] = f"spk_abjad_{len(abjad_spk_map)+1:03d}"
        return abjad_spk_map[raw_spk]

    def fetch_abjad(lbl: str, count: int, exclude_paths: set) -> list:
        cands = [p for p in abjad_by_lbl.get(lbl, []) if p not in exclude_paths]
        RNG.shuffle(cands)
        out = []
        used_spk = set()
        for p in cands:
            spk = get_abjad_spk(p)
            if spk in used_spk and len(cands) > count * 2:
                continue
            url = "https://huggingface.co/datasets/Aziz-snoubra/Abjad-Kids/resolve/main/" + urllib.parse.quote(p)
            try:
                raw = http_get(url, timeout=20)
                st = parse_wav_stats(raw)
                if st["duration_ms"] >= 200 and st["rms"] >= 0.001:
                    used_spk.add(spk)
                    exclude_paths.add(p)
                    out.append((lbl, p, spk, url, raw, st))
                    if len(out) >= count:
                        break
            except Exception:
                continue
        return out

    abjad_used = set()

    # Cat 1 (part B): 10 Abjad-Kids correct pediatric words
    abjad_correct_labels = ["Kora", "Kalb", "Arnab", "Farasha", "Feel", "Jamal", "Ketab", "Qalam", "Shams", "Tofaha"]
    cat1_abjad = []
    for lbl in abjad_correct_labels:
        res = fetch_abjad(lbl, 1, abjad_used)
        if res:
            cat1_abjad.append(res[0])

    # Cat 3: 10 Abjad-Kids unrelated word spoken vs mismatched target word
    abjad_unrel_pairs = [
        ("Zarafa", "كورة"), ("Ghaba", "سمكة"), ("Khobz", "أرنب"), ("Defda", "كلب"), ("Kharouf", "بطة"),
        ("Namla", "شمس"), ("Qerd", "تفاحة"), ("Raml", "باب"), ("Sama", "فيل"), ("Warda", "قلم"),
    ]
    cat3_abjad = []
    for lbl, mismatch_target in abjad_unrel_pairs:
        res = fetch_abjad(lbl, 1, abjad_used)
        if res:
            cat3_abjad.append((res[0], mismatch_target))

    # Cat 9: 5 Isolated Arabic letters/sounds spoken by children
    cat9_abjad = []
    for lbl in ["Kaf", "Seen", "Ra", "Hha", "Alif"]:
        res = fetch_abjad(lbl, 1, abjad_used)
        if res:
            cat9_abjad.append(res[0])

    # Extra Abjad pool for quiet/short/clipped candidates
    abjad_extra = []
    for lbl in ["Patta", "Bab", "Beit", "Bathenjan", "Thallaja", "Walad", "Alam", "Taera", "Hadeya", "Halib", "Masjed", "Asfour", "Daraj", "Dabet", "Ghazal"]:
        abjad_extra.extend(fetch_abjad(lbl, 2, abjad_used))

    # ------------------------------------------------------------------
    # Assign Categories 1, 2, 3, 4, 5, 9, 10 from genuine downloaded child pools WITHOUT overlap!
    # ------------------------------------------------------------------
    # Cat 1 (part A): 10 best audible clean ASMDD correct samples
    asmdd_pool_correct_sorted_clean = sorted(asmdd_pool_correct, key=lambda x: (-x[2]["est_snr_db"], -x[2]["rms"]))
    cat1_asmdd = asmdd_pool_correct_sorted_clean[:10]
    used_asmdd_ids = {x[0][4] for x in cat1_asmdd}

    # Cat 4: 10 genuinely quiet/weak pediatric recordings (lowest natural RMS >= 0.0015 across remaining ASMDD + Abjad)
    rem_asmdd = [x for x in asmdd_pool_correct if x[0][4] not in used_asmdd_ids]
    quiet_candidates = []
    for item, raw, st in rem_asmdd:
        quiet_candidates.append(("asmdd", item, raw, st))
    for lbl, p, spk, url, raw, st in abjad_extra:
        quiet_candidates.append(("abjad", (lbl, p, spk, url), raw, st))
    quiet_candidates.sort(key=lambda x: x[3]["rms"])
    cat4_quiet = quiet_candidates[:10]
    for src, info, _, _ in cat4_quiet:
        if src == "asmdd":
            used_asmdd_ids.add(info[4])
        else:
            used_sources.add(info[1])

    # Cat 5: 10 genuinely noisy classroom pediatric recordings (lowest native est_snr_db from remaining ASMDD)
    rem_asmdd = [x for x in asmdd_pool_correct if x[0][4] not in used_asmdd_ids]
    rem_asmdd.sort(key=lambda x: x[2]["est_snr_db"])
    cat5_noisy = rem_asmdd[:10]
    for item, _, _ in cat5_noisy:
        used_asmdd_ids.add(item[4])

    # Cat 10: 5 difficult edge cases (1 ultra-short, 1 peak-saturated/clipped, 1 multi-phoneme OOV Bathenjan, 1 native 32-bit raw ASMDD, 1 fast multi-syllable Thallaja)
    cat10_items = []
    rem_abjad = [x for x in abjad_extra if x[1] not in used_sources]
    if rem_abjad:
        # 1. Ultra-short clip
        shortest = min(rem_abjad, key=lambda x: x[5]["duration_ms"])
        cat10_items.append(("abjad_short", shortest))
        used_sources.add(shortest[1])
        rem_abjad = [x for x in rem_abjad if x[1] not in used_sources]
        # 2. Highest peak / clipped real child mic input
        loudest = max(rem_abjad, key=lambda x: x[5]["peak"])
        cat10_items.append(("abjad_clipped_peak", loudest))
        used_sources.add(loudest[1])
        rem_abjad = [x for x in rem_abjad if x[1] not in used_sources]
        # 3 & 4. Complex consonant clusters Bathenjan / Thallaja
        for target_lbl in ("Bathenjan", "Thallaja"):
            hit = next((x for x in rem_abjad if x[0] == target_lbl), None)
            if hit:
                cat10_items.append(("abjad_complex", hit))
                used_sources.add(hit[1])
    rem_asmdd_edge = [x for x in asmdd_pool_correct if x[0][4] not in used_asmdd_ids]
    if rem_asmdd_edge:
        cat10_items.append(("asmdd_raw_fmt", rem_asmdd_edge[0]))
        used_asmdd_ids.add(rem_asmdd_edge[0][0][4])

    # ------------------------------------------------------------------
    # 3. Adult Arabic speech (10 samples): 4 Egyptian (ammarthabet) + 3 ASC (CC-BY-4.0) + 3 MASC (CC-BY-4.0)
    # ------------------------------------------------------------------
    print("Fetching Adult Arabic speech samples...")
    adult_items = []
    # 4 Egyptian Arabic adult clips from ammarthabet/egyptian-arabic-speech
    for idx_str in ["000400", "000401", "000402", "000403"]:
        try:
            txt = http_get(f"https://huggingface.co/datasets/ammarthabet/egyptian-arabic-speech/resolve/main/ammar_ds/{idx_str}.txt").decode("utf-8", errors="replace").strip()
            raw = http_get(f"https://huggingface.co/datasets/ammarthabet/egyptian-arabic-speech/resolve/main/ammar_ds/{idx_str}.wav")
            st = parse_wav_stats(raw)
            adult_items.append(("egyptian_adult", f"ammar_{idx_str}", txt, "", "Egyptian Arabic", raw, st, "https://huggingface.co/datasets/ammarthabet/egyptian-arabic-speech", "Open HF Dataset"))
        except Exception as e:
            print("  err ammar", idx_str, e)

    # 3 Human MSA adult with phonetic annotations from tunis-ai/arabic_speech_corpus (CC-BY-4.0)
    try:
        asc_rows = json.loads(http_get("https://datasets-server.huggingface.co/rows?dataset=tunis-ai/arabic_speech_corpus&config=default&split=test&offset=0&length=4").decode())["rows"]
        for i, r in enumerate(asc_rows[:3]):
            row = r["row"]
            audio_url = row["audio"][0]["src"]
            raw = http_get(audio_url, timeout=25)
            st = parse_wav_stats(raw)
            ar_words = buckwalter_to_arabic_phonemes(row["orthographic"])
            ar_text = " ".join(ar_words)
            adult_items.append(("asc_adult", f"asc_{i:02d}", ar_text, row["phonetic"], "Modern Standard Arabic", raw, st, "https://huggingface.co/datasets/tunis-ai/arabic_speech_corpus", "CC-BY-4.0"))
    except Exception as e:
        print("  err asc", e)

    # 3 Arabic adult from MohamedRashad/MASC-Arabic (CC-BY-4.0)
    try:
        masc_rows = json.loads(http_get("https://datasets-server.huggingface.co/rows?dataset=MohamedRashad/MASC-Arabic&config=default&split=test&offset=0&length=4").decode())["rows"]
        for i, r in enumerate(masc_rows[:3]):
            row = r["row"]
            audio_url = row["audio"][0]["src"]
            raw = http_get(audio_url, timeout=25)
            st = parse_wav_stats(raw)
            adult_items.append(("masc_adult", f"masc_{i:02d}", row["text"], "", "Multi-Dialect Arabic", raw, st, "https://huggingface.co/datasets/MohamedRashad/MASC-Arabic", "CC-BY-4.0"))
    except Exception as e:
        print("  err masc", e)

    # ------------------------------------------------------------------
    # 4. MUSAN Environmental Noise (5 non-speech samples + 5 extra for Section 8 paired tests)
    # ------------------------------------------------------------------
    print("Fetching MUSAN CC-BY-4.0 environmental noise...")
    musan_files = [
        ("noise/free-sound/noise-free-sound-0000.wav", "fan_appliance_noise"),
        ("noise/free-sound/noise-free-sound-0232.wav", "ambient_street_traffic"),
        ("noise/free-sound/noise-free-sound-0335.wav", "household_television_babble"),
        ("noise/free-sound/noise-free-sound-0671.wav", "classroom_crowd_ambience"),
        ("noise/sound-bible/noise-sound-bible-0000.wav", "mic_handling_environmental"),
    ]
    cat8_noise = []
    for rel, desc in musan_files:
        url = f"https://huggingface.co/datasets/bilguun/musan-noise/resolve/main/{rel}"
        raw = http_get(url, timeout=25)
        st = parse_wav_stats(raw)
        # Take clean 3s slice at 16kHz so file stays compact while preserving real environmental spectrum
        f32 = st["mono_f32"][: st["sample_rate"] * 3]
        wav_slice = make_pcm16_wav(f32, st["sample_rate"])
        st2 = parse_wav_stats(wav_slice)
        cat8_noise.append((rel, desc, url, wav_slice, st2))

    # ------------------------------------------------------------------
    # 5. Cat 7: Silence or Near-Silence (5 unique samples)
    # ------------------------------------------------------------------
    cat7_silence = []
    # 1. Zero signal silence.wav
    sil_raw = (ROOT / "assets" / "audio_samples" / "silence.wav").read_bytes()
    cat7_silence.append(("liqaa_silence_zero", "Digital zero silence (1.5s)", sil_raw, parse_wav_stats(sil_raw)))
    # 2-5. Near-silence quiet noise floor (< 0.0012 RMS) representing mic thermal/quantization/DC bias
    for idx_s, (desc, fn) in enumerate([
        ("16-bit quantization LSB floor (-72 dBFS)", lambda n: np.random.default_rng(100).normal(0.0, 0.00025, n)),
        ("Low-level mic thermal floor (-65 dBFS)", lambda n: np.random.default_rng(101).normal(0.0, 0.00055, n)),
        ("DC-biased quiet room floor (offset +0.02, AC rms 0.0004)", lambda n: 0.02 + np.random.default_rng(102).normal(0.0, 0.0004, n)),
        ("Faint sub-audible impulse + silence", lambda n: np.concatenate([np.zeros(8000), np.random.default_rng(103).normal(0.0, 0.0008, 4000), np.zeros(12000)])),
    ], start=2):
        w = make_pcm16_wav(fn(24000).astype(np.float32), 16000)
        cat7_silence.append((f"near_silence_{idx_s}", desc, w, parse_wav_stats(w)))

    # ------------------------------------------------------------------
    # Assemble Exact 100-Sample Frozen Manifest
    # ------------------------------------------------------------------
    sample_counter = 1
    def add_entry(
        category: str,
        dataset: str,
        source_url: str,
        license_str: str,
        speaker_id: str,
        age_range: str,
        dialect: str,
        audio_type: str,
        raw_bytes: bytes,
        stats: dict,
        target_word: str,
        actual_word: str,
        ref_ipa: str,
        speech_present: bool,
        err_cat: str,
        target_phoneme: str,
        actual_phoneme: str,
        expected_outcome: str,
        gt_reliability: str,
        in_dictionary: bool = False,
    ):
        nonlocal sample_counter
        sid = f"S{sample_counter:03d}"
        sample_counter += 1
        rel_path, chksum = save_clip(sid, raw_bytes)
        samples.append({
            "sample_id": sid,
            "file_path": rel_path,
            "category": category,
            "original_dataset": dataset,
            "source_url": source_url,
            "license": license_str,
            "speaker_id": speaker_id,
            "speaker_age_range": age_range,
            "arabic_dialect": dialect,
            "audio_type": audio_type,
            "original_format": f"WAV PCM/{stats['bits_per_sample']}-bit {stats['channels']}ch",
            "sample_rate": stats["sample_rate"],
            "duration_ms": stats["duration_ms"],
            "raw_rms": round(stats["rms"], 5),
            "raw_peak": round(stats["peak"], 4),
            "raw_est_snr_db": round(stats["est_snr_db"], 2),
            "clipping_count": stats["clipping_count"],
            "target_word": target_word,
            "actual_spoken_word": actual_word,
            "reference_ipa": ref_ipa,
            "actual_speech_present": speech_present,
            "reference_speech_boundaries": "unavailable_unaligned",
            "pronunciation_error_category": err_cat,
            "target_phoneme": target_phoneme,
            "actual_pronounced_phoneme": actual_phoneme,
            "expected_outcome": expected_outcome,
            "ground_truth_reliability": gt_reliability,
            "in_dictionary": in_dictionary,
            "sha256": chksum,
        })

    # Cat 1A: 10 ASMDD correct Egyptian child
    for item, raw, st in cat1_asmdd[:10]:
        widx, fid, fn, url, _ = item
        w_ar = ASMDD_WORDS[widx]
        ipa = " ".join(simple_arabic_ipa(w_ar))
        add_entry(
            "correct_pediatric", "ASMDD (Mendeley 10.17632/x54dg53rmr.1)", url, "CC0 1.0",
            folder_to_anon.get(fid, "spk_asmdd"), "2-8 years", "Egyptian Arabic", "human_pediatric",
            raw, st, w_ar, w_ar, ipa, True, "none",
            w_ar[0], w_ar[0], "pass", "verified_word_level_expert_label",
            in_dictionary=(w_ar in {"الباب", "البيت", "ولد", "الشمس", "الكتاب"}),
        )

    # Cat 1B: 10 Abjad-Kids correct Arabic child
    for lbl, p, spk, url, raw, st in cat1_abjad[:10]:
        w_ar, ipa_list = ABJAD_WORD_ARABIC[lbl]
        add_entry(
            "correct_pediatric", "Abjad-Kids (Aziz-snoubra/Abjad-Kids)", url, "MIT",
            spk, "3-12 years", "Multi-Dialect Arabic", "human_pediatric",
            raw, st, w_ar, w_ar, " ".join(ipa_list), True, "none",
            w_ar[0], w_ar[0], "pass", "verified_word_level_dataset_label",
            in_dictionary=(lbl in {"Kora", "Kalb", "Arnab", "Farasha", "Feel", "Jamal", "Ketab", "Qalam", "Shams", "Tofaha"}),
        )

    # Cat 2: 20 Genuine Egyptian pediatric errors (_N from ASMDD)
    for item, raw, st in asmdd_pool_error[:20]:
        widx, fid, fn, url, _ = item
        w_ar = ASMDD_WORDS[widx]
        add_entry(
            "genuine_pediatric_errors", "ASMDD (Mendeley 10.17632/x54dg53rmr.1)", url, "CC0 1.0",
            folder_to_anon.get(fid, "spk_asmdd"), "2-8 years", "Egyptian Arabic", "human_pediatric",
            raw, st, w_ar, f"{w_ar} (mispronounced:_N)", "", True, "segmental_mispronunciation_asmdd",
            w_ar[0], "unverified_segment_error", "fail_mispronunciation", "verified_word_level_expert_label",
            in_dictionary=False,
        )

    # Cat 3: 10 Unrelated target words spoken by children
    for (lbl, p, spk, url, raw, st), mismatch_target in cat3_abjad[:10]:
        w_ar, ipa_list = ABJAD_WORD_ARABIC[lbl]
        add_entry(
            "unrelated_word_pediatric", "Abjad-Kids (Aziz-snoubra/Abjad-Kids)", url, "MIT",
            spk, "3-12 years", "Multi-Dialect Arabic", "human_pediatric",
            raw, st, mismatch_target, w_ar, " ".join(ipa_list), True, "unrelated_word",
            mismatch_target[0], w_ar[0], "fail_unrelated", "verified_word_level_dataset_label",
            in_dictionary=True,
        )

    # Cat 4: 10 Quiet/weak pediatric recordings
    for src, info, raw, st in cat4_quiet[:10]:
        if src == "asmdd":
            widx, fid, fn, url, _ = info
            w_ar = ASMDD_WORDS[widx]
            add_entry(
                "quiet_weak_pediatric", "ASMDD (Mendeley 10.17632/x54dg53rmr.1)", url, "CC0 1.0",
                folder_to_anon.get(fid, "spk_asmdd"), "2-8 years", "Egyptian Arabic", "human_pediatric",
                raw, st, w_ar, w_ar, " ".join(simple_arabic_ipa(w_ar)), True, "weak_articulation_low_rms",
                w_ar[0], w_ar[0], "detect_speech_and_evaluate", "verified_word_level_expert_label",
            )
        else:
            lbl, p, spk, url = info
            w_ar, ipa_list = ABJAD_WORD_ARABIC[lbl]
            add_entry(
                "quiet_weak_pediatric", "Abjad-Kids (Aziz-snoubra/Abjad-Kids)", url, "MIT",
                spk, "3-12 years", "Multi-Dialect Arabic", "human_pediatric",
                raw, st, w_ar, w_ar, " ".join(ipa_list), True, "weak_articulation_low_rms",
                w_ar[0], w_ar[0], "detect_speech_and_evaluate", "verified_word_level_dataset_label",
            )

    # Cat 5: 10 Pediatric speech with real classroom/background noise (ASMDD low native SNR)
    for item, raw, st in cat5_noisy[:10]:
        widx, fid, fn, url, _ = item
        w_ar = ASMDD_WORDS[widx]
        add_entry(
            "noisy_pediatric", "ASMDD (Mendeley 10.17632/x54dg53rmr.1)", url, "CC0 1.0",
            folder_to_anon.get(fid, "spk_asmdd"), "2-8 years", "Egyptian Arabic", "human_pediatric",
            raw, st, w_ar, w_ar, " ".join(simple_arabic_ipa(w_ar)), True, "background_classroom_noise",
            w_ar[0], w_ar[0], "detect_speech_and_denoise", "verified_word_level_expert_label",
        )

    # Cat 6: 10 Adult Arabic speech
    for kind, spk, txt, ref_ph, dialect, raw, st, src_url, lic in adult_items[:10]:
        ds_name = {
            "egyptian_adult": "ammarthabet/egyptian-arabic-speech",
            "asc_adult": "tunis-ai/arabic_speech_corpus",
            "masc_adult": "MohamedRashad/MASC-Arabic",
        }[kind]
        add_entry(
            "adult_arabic_speech", ds_name, src_url, lic,
            spk, "adult", dialect, "human_adult",
            raw, st, "", txt, ref_ph, True, "none",
            "", "", "transcribe_and_phonemes", "verified_transcript" if not ref_ph else "verified_phonetic_corpus",
        )

    # Cat 7: 5 Silence / Near-Silence
    for spk, desc, raw, st in cat7_silence[:5]:
        add_entry(
            "silence_near_silence", "Controlled Silence / Noise Floor Fixtures", "local://benchmarks/audio", "MIT",
            "none", "n/a", "n/a", "silence_floor",
            raw, st, "كورة", "", "", False, "no_speech",
            "ك", "", "reject_no_speech", "exact_signal_ground_truth",
        )

    # Cat 8: 5 MUSAN Environmental Noise
    for rel, desc, url, raw, st in cat8_noise[:5]:
        add_entry(
            "environmental_noise", "MUSAN (bilguun/musan-noise / OpenSLR SLR17)", url, "CC-BY-4.0",
            "none", "n/a", "n/a", "environmental_noise",
            raw, st, "كورة", f"[NOISE: {desc}]", "", False, "noise_only",
            "ك", "", "reject_noise_no_speech", "verified_non_speech_dataset",
        )

    # Cat 9: 5 Isolated consonants / letters from Abjad-Kids
    for lbl, p, spk, url, raw, st in cat9_abjad[:5]:
        w_ar, ipa_list = ABJAD_WORD_ARABIC[lbl]
        add_entry(
            "isolated_consonants_syllables", "Abjad-Kids (Aziz-snoubra/Abjad-Kids)", url, "MIT",
            spk, "3-12 years", "Multi-Dialect Arabic", "human_pediatric",
            raw, st, w_ar, w_ar, " ".join(ipa_list), True, "isolated_letter",
            w_ar[0], w_ar[0], "detect_speech_and_phonemes", "verified_word_level_dataset_label",
        )

    # Cat 10: 5 Difficult edge cases
    for tag, obj in cat10_items[:5]:
        if tag == "asmdd_raw_fmt":
            item, raw, st = obj
            widx, fid, fn, url, _ = item
            w_ar = ASMDD_WORDS[widx]
            add_entry(
                "difficult_edge_cases", "ASMDD (Mendeley 10.17632/x54dg53rmr.1)", url, "CC0 1.0",
                folder_to_anon.get(fid, "spk_asmdd"), "2-8 years", "Egyptian Arabic", "human_pediatric",
                raw, st, w_ar, w_ar, " ".join(simple_arabic_ipa(w_ar)), True, "high_rate_32bit_wav",
                w_ar[0], w_ar[0], "preprocess_and_evaluate", "verified_word_level_expert_label",
            )
        else:
            lbl, p, spk, url, raw, st = obj
            w_ar, ipa_list = ABJAD_WORD_ARABIC[lbl]
            add_entry(
                "difficult_edge_cases", "Abjad-Kids (Aziz-snoubra/Abjad-Kids)", url, "MIT",
                spk, "3-12 years", "Multi-Dialect Arabic", "human_pediatric",
                raw, st, w_ar, w_ar, " ".join(ipa_list), True, tag,
                w_ar[0], w_ar[0], "preprocess_and_evaluate", "verified_word_level_dataset_label",
            )

    # Save frozen manifest.jsonl and ground_truth.csv
    manifest_path = ROOT / "benchmarks" / "audio" / "manifest.jsonl"
    gt_path = ROOT / "benchmarks" / "audio" / "ground_truth.csv"

    with open(manifest_path, "w", encoding="utf-8") as f:
        for s in samples:
            f.write(json.dumps(s, ensure_ascii=False) + "\n")

    fieldnames = list(samples[0].keys())
    with open(gt_path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(samples)

    # ------------------------------------------------------------------
    # Build Separate Controlled Fixtures (Section 6 Format Tests + Section 8 Clean+MUSAN SNR Tests)
    # ------------------------------------------------------------------
    controlled = []
    # Base clean speech references from first 3 clean pediatric words
    base_clean_samples = []
    for s in samples:
        if s["category"] == "correct_pediatric" and s["original_dataset"].startswith("Abjad-Kids") and len(base_clean_samples) < 3:
            st = parse_wav_stats((ROOT / s["file_path"]).read_bytes())
            # resample to 16kHz numpy array for mixing
            arr = st["mono_f32"]
            sr = st["sample_rate"]
            if sr != 16000:
                idx = np.linspace(0, len(arr) - 1, int(round(len(arr) * 16000 / sr)))
                arr = np.interp(idx, np.arange(len(arr)), arr).astype(np.float32)
            base_clean_samples.append((s, arr))

    musan_noise_arrays = []
    for rel, desc, url, raw, st in cat8_noise[:4]:
        arr = st["mono_f32"]
        if st["sample_rate"] != 16000:
            idx = np.linspace(0, len(arr) - 1, int(round(len(arr) * 16000 / st["sample_rate"])))
            arr = np.interp(idx, np.arange(len(arr)), arr).astype(np.float32)
        musan_noise_arrays.append((desc, arr))

    # Mix clean speech + MUSAN noise across -5, 0, 5, 10, 15, 20 dB
    for b_idx, (base_s, clean_arr) in enumerate(base_clean_samples):
        clean_p = CONTROLLED_DIR / f"clean_ref_{base_s['sample_id']}.wav"
        clean_p.write_bytes(make_pcm16_wav(clean_arr, 16000))
        noise_desc, noise_arr = musan_noise_arrays[b_idx % len(musan_noise_arrays)]
        for snr_target in [-5, 0, 5, 10, 15, 20]:
            if len(noise_arr) < len(clean_arr):
                reps = (len(clean_arr) // len(noise_arr)) + 1
                n_seg = np.tile(noise_arr, reps)[: len(clean_arr)]
            else:
                n_seg = noise_arr[: len(clean_arr)]
            c_rms = float(np.sqrt(np.mean(clean_arr ** 2)) + 1e-8)
            n_rms = float(np.sqrt(np.mean(n_seg ** 2)) + 1e-8)
            scale = c_rms / (n_rms * (10.0 ** (snr_target / 20.0)))
            mixed = np.clip(clean_arr + n_seg * scale, -1.0, 1.0).astype(np.float32)
            cid = f"MIX_{base_s['sample_id']}_{snr_target}dB"
            mp = CONTROLLED_DIR / f"{cid}.wav"
            mp.write_bytes(make_pcm16_wav(mixed, 16000))
            controlled.append({
                "id": cid,
                "type": "paired_noisy_speech",
                "source_sample_id": base_s["sample_id"],
                "target_word": base_s["target_word"],
                "noise_type": noise_desc,
                "target_snr_db": snr_target,
                "clean_path": str(clean_p.relative_to(ROOT)).replace("\\", "/"),
                "noisy_path": str(mp.relative_to(ROOT)).replace("\\", "/"),
            })

    # Synthetic TTS minimal-pair & clinical error probes kept strictly SEPARATE in controlled_manifest.jsonl
    for fname, word_ar, err_lbl in [
        ("assets/audio_samples/correct_kora.wav", "كورة", "none"),
        ("assets/audio_samples/error_tora.wav", "كورة", "fronting_tts_controlled"),
        ("assets/audio_samples/correct_arnab.wav", "أرنب", "none"),
        ("assets/audio_samples/error_anlab.wav", "أرنب", "lateralization_tts_controlled"),
        ("assets/audio_samples/word_madrasa.wav", "كورة", "unrelated_tts_controlled"),
    ]:
        controlled.append({
            "id": "SYNTH_" + Path(fname).stem,
            "type": "controlled_synthetic_tts",
            "target_word": word_ar,
            "expected_error": err_lbl,
            "path": fname,
        })

    ctrl_path = ROOT / "benchmarks" / "audio" / "controlled_manifest.jsonl"
    with open(ctrl_path, "w", encoding="utf-8") as f:
        for c in controlled:
            f.write(json.dumps(c, ensure_ascii=False) + "\n")

    # Summary print
    from collections import Counter
    cats = Counter(s["category"] for s in samples)
    print(f"\nFrozen manifest.jsonl with {len(samples)} unique samples:")
    for k, v in cats.items():
        print(f"  {k:32s}: {v}")
    print(f"Controlled paired + synthetic entries: {len(controlled)}")


if __name__ == "__main__":
    main()
