with open("tools/rive_strings.txt", "r", encoding="utf-8") as f:
    lines = [line.strip() for line in f if line.strip()]

# Filter strings that look like identifiers (not garbage or binary chunks)
import re
id_pattern = re.compile(r'^[A-Za-z0-9_\-\. ]{2,50}$')
identifiers = [l for l in lines if id_pattern.match(l)]

print(f"Total valid identifier-like strings: {len(identifiers)}")

# Search for specific terms
terms = [
    "idle", "wave", "walk", "run", "jump", "talk", "listen", "smile", "blink",
    "look", "gaze", "head", "eye", "input", "state", "machine", "artboard",
    "password", "name", "email", "typing", "success", "error", "fail", "win",
    "celebrat", "confus", "think", "happy", "sad", "hand", "arm", "cover", "peek",
    "validation", "layer", "yasser", "root"
]

found = {}
for term in terms:
    matches = [i for i in identifiers if term in i.lower()]
    if matches:
        found[term] = matches

for term, matches in sorted(found.items()):
    print(f"\n=== Term: {term} ({len(matches)}) ===")
    for m in sorted(set(matches)):
        print(f"  {m}")
