import struct
import re
import os

riv_path = r"assets\rive\yasser.riv"
with open(riv_path, "rb") as f:
    data = f.read()

print(f"File size: {len(data)} bytes")
header = data[:4]
print(f"Header: {header}")
major, minor = struct.unpack("<HH", data[4:8])
print(f"Version: major={major}, minor={minor}")

# Find all printable ASCII / UTF-8 strings of length >= 3
strings = re.findall(b"[\x20-\x7E]{3,}", data)
decoded_strings = [s.decode("latin1") for s in strings]

print(f"\nTotal extracted strings (>=3 chars): {len(decoded_strings)}")

# Look for keywords related to artboards, animations, inputs, state machines, bones, joints
keywords = [
    "artboard", "state", "machine", "anim", "input", "bone", "joint", "root",
    "arm", "hand", "eye", "head", "face", "mouth", "idle", "wave", "walk",
    "yasser", "look", "password", "cover", "blink", "smile", "happy", "peek",
    "listen", "talk", "trigger", "number", "bool"
]

matching = {}
for s in decoded_strings:
    s_lower = s.lower()
    for kw in keywords:
        if kw in s_lower:
            matching.setdefault(kw, set()).add(s)

print("\n--- Matching strings by category ---")
for kw, matches in sorted(matching.items()):
    print(f"[{kw}] ({len(matches)} matches):")
    for m in sorted(matches)[:15]:
        print(f"  - {m}")
    if len(matches) > 15:
        print(f"  ... and {len(matches) - 15} more")

# Output full unique string list to a file for full auditing
with open("tools/rive_strings.txt", "w", encoding="utf-8") as f:
    for s in sorted(set(decoded_strings)):
        f.write(s + "\n")

print("\nSaved all strings to tools/rive_strings.txt")
