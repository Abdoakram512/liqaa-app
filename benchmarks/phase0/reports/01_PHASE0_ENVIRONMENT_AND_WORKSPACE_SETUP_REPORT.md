# 01 — Phase 0 Environment & Workspace Setup Report

Generated UTC: `2026-11-27T06:16:10.971125+00:00`

## Verified Hardware & Storage State
- **C: Drive (System):** `31.02 GB` free / `247.1 GB` total (**CRITICAL BOTTLENECK** — policy blocks all ML installs/caches on `C:`).
- **D: Drive (Dedicated ML Root `D:\YasserML`):** `271.22 GB` free / `931.5 GB` total.
- **E: Drive (Git Workspace `E:\Flutter Projects\liqaa_app`):** `101.14 GB` free / `227.12 GB` total.
- **GPU Observed Earlier in Session Audit:** NVIDIA GeForce GTX 1650 Ti (4096 MiB VRAM); Phase 0 executed CPU-only without training or large model downloads.

## `D:\YasserML` Directory Structure & Config
Configuration persisted at `D:\YasserML\workspace_config.json`:
- `D:\YasserML\models`
- `D:\YasserML\datasets\raw`
- `D:\YasserML\datasets\processed`
- `D:\YasserML\manifests`
- `D:\YasserML\manifests\blind_vault_external` (externalized blind Stage B label storage)
- `D:\YasserML\cache\huggingface`, `torch`, `pip`, `tmp`
- `D:\YasserML\reports`
- `D:\YasserML\checkpoints`
- `D:\YasserML\quarantine`

## Runtime Cache Isolation
All scripts configure non-C: environment targets cleanly per process (`HF_HOME`, `TORCH_HOME`, `PIP_CACHE_DIR` -> `D:\YasserML\cache\*`) without modifying system-wide Windows user data or deleting personal files.
