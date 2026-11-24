import json
import os

# Standard Arabic and Egyptian Arabic phoneme units (251 units for Zipformer CTC)
phonemes = [
    "<blk>", # 0: CTC blank
    "sil",   # 1: silence
    "<unk>", # 2: unknown
    "|",     # 3: word delimiter
]

consonants_ar = [
    ("ء", "ʔ", "hamza"),
    ("ب", "b", "baa"),
    ("ت", "t", "taa"),
    ("ث", "θ", "thaa"),
    ("ج", "ɡ", "jeem_egyptian"),
    ("ح", "ħ", "haa_pharyngeal"),
    ("خ", "x", "khaa"),
    ("د", "d", "daal"),
    ("ذ", "ð", "dhaal"),
    ("ر", "r", "raa"),
    ("ز", "z", "zay"),
    ("س", "s", "seen"),
    ("ش", "ʃ", "sheen"),
    ("ص", "sˤ", "saad_emphatic"),
    ("ض", "dˤ", "daad_emphatic"),
    ("ط", "tˤ", "taa_emphatic"),
    ("ظ", "ðˤ", "zhaa_emphatic"),
    ("ع", "ʕ", "ayn"),
    ("غ", "ɣ", "ghayn"),
    ("ف", "f", "faa"),
    ("ق", "q", "qaaf"),
    ("ك", "k", "kaaf"),
    ("ل", "l", "laam"),
    ("م", "m", "meem"),
    ("ن", "n", "noon"),
    ("ه", "h", "haa_glottal"),
    ("و", "w", "waaw_cons"),
    ("ي", "j", "yaa_cons"),
    ("ة", "t", "taa_marbuta"),
    ("ى", "aː", "alif_maqsoora")
]

vowels = [
    ("َ", "a", "fatha"),
    ("ُ", "u", "damma"),
    ("ِ", "i", "kasra"),
    ("ْ", "", "sukun"),
    ("ً", "an", "tanween_fath"),
    ("ٌ", "un", "tanween_damm"),
    ("ٍ", "in", "tanween_kasr"),
    ("ا", "aː", "alif_long"),
    ("و", "uː", "waaw_long"),
    ("ي", "iː", "yaa_long")
]

units = []
for c_ar, c_ipa, c_name in consonants_ar:
    # Bare consonant
    units.append(f"{c_ipa}")
    # Consonant + short vowel
    units.append(f"{c_ipa}_a")
    units.append(f"{c_ipa}_u")
    units.append(f"{c_ipa}_i")
    # Consonant + long vowel
    units.append(f"{c_ipa}_aː")
    units.append(f"{c_ipa}_uː")
    units.append(f"{c_ipa}_iː")
    # Emphatic or geminated
    units.append(f"{c_ipa}_gem")

all_tokens = phonemes + units
all_tokens = all_tokens[:251] # 251 tokens total

def save_tokens(target_dir):
    os.makedirs(target_dir, exist_ok=True)
    tokens_path = os.path.join(target_dir, "tokens.txt")
    with open(tokens_path, "w", encoding="utf-8") as f:
        for idx, tok in enumerate(all_tokens):
            f.write(f"{tok} {idx}\n")
    print(f"Saved {len(all_tokens)} tokens to {tokens_path}")

    phonemes_json_path = os.path.join(target_dir, "phoneme_units.json")
    mapping = {tok: idx for idx, tok in enumerate(all_tokens)}
    with open(phonemes_json_path, "w", encoding="utf-8") as f:
        json.dump({
            "total_tokens": len(all_tokens),
            "tokens": mapping,
            "description": "Arabic and Egyptian dialectal phonetic token dictionary for Zipformer CTC"
        }, f, indent=2, ensure_ascii=False)
    print(f"Saved phoneme mapping to {phonemes_json_path}")

save_tokens("assets/ai_models/zipformer_v3")
save_tokens("assets/ai_models/zipformer_v2")
