# 11 — Storage & Hardware Constraints Report

- **`C:` Drive Critical Alert:** Only **`31.02 GB`** free (`216.08 GB` / `247.1 GB` used). Installing Python packages, Hugging Face hubs, or Android/Flutter build caches onto `C:` risks OS failure.
- **`D:\YasserML` Approved Storage:** **`271.22 GB`** free (`931.5 GB` total) handles all datasets, checkpoints, caches, and quarantine logs cleanly.
- **`E:` Repo Drive:** **`101.14 GB`** free (`227.12 GB` total).
- **GPU & RAM Notes:** Local GTX 1650 Ti (4 GB VRAM) + limited system RAM (~2–4 GB available under load) restrict local execution strictly to sequential CPU/small ONNX inference; full Stage A/B training/large teachers (Whisper-Large-v3-Turbo, XLSR-300M fine-tuning) remain reserved for external GPU (Kaggle/cloud) with local ONNX quantized verification only.
